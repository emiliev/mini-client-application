"""macOS process-tree sampler (T-0016 AC6, AC7; plan 04 KD-2, §6.4).

The budget metric is the sum of `phys_footprint` over the process tree (what jetsam counts). ΣRSS is
recorded next to it. Everything is read through libproc with ctypes, so a sample forks nothing:
 - pid list:   proc_listallpids; parent pid from proc_pidinfo(PROC_PIDTBSDINFO), cached per pid
 - memory/CPU: proc_pid_rusage(RUSAGE_INFO_V4): ri_phys_footprint, ri_resident_size,
               ri_lifetime_max_phys_footprint, user/system time in mach ticks
 - argv:       sysctl KERN_PROCARGS2, read once per new pid (fallback: `ps -p`)
System series (1 s): `vm_stat` swapouts, `sysctl vm.swapusage` and kern.memorystatus_vm_pressure_level.
`ps -axo pid=,ppid=,rss=` is the fallback when libproc is unavailable (no ri_phys_footprint then).
"""
import csv
import ctypes
import ctypes.util
import gzip
import json
import os
import re
import struct
import subprocess
import sys
import threading
import time

RUSAGE_INFO_V4 = 4
PROC_PIDTBSDINFO = 3
# Indexes into the u64 array that follows the 16-byte ri_uuid of rusage_info_v4.
I_USER, I_SYS, I_RESIDENT, I_FOOTPRINT, I_START, I_LIFETIME_MAX = 0, 1, 6, 7, 8, 28

_libc = ctypes.CDLL(ctypes.util.find_library("c") or "/usr/lib/libSystem.B.dylib", use_errno=True)
_libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)


class _Timebase(ctypes.Structure):
    _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]


def _timebase():
    tb = _Timebase()
    _libc.mach_timebase_info(ctypes.byref(tb))
    return tb.numer / tb.denom


MACH_TO_NS = _timebase()
# Buffers are allocated per call: the sampler runs two threads and module-level buffers would race.


_TLS = threading.local()  # per-thread ctypes buffers: no sharing between the two sampler threads
_RU_STRUCT = struct.Struct("<48Q")
_NS_TO_S = 1e-9


def rusage(pid):
    """(footprint, rss, cpu_s, lifetime_max_footprint, start_abstime) or None if gone/denied.
    start_abstime identifies the process incarnation (pids are reused)."""
    buf = getattr(_TLS, "ru", None)
    if buf is None:
        buf = _TLS.ru = ctypes.create_string_buffer(16 + 8 * 48)
    if _libproc.proc_pid_rusage(pid, RUSAGE_INFO_V4, buf) != 0:
        return None
    v = _RU_STRUCT.unpack_from(buf, 16)
    cpu = (v[I_USER] + v[I_SYS]) * MACH_TO_NS * _NS_TO_S
    return v[I_FOOTPRINT], v[I_RESIDENT], cpu, v[I_LIFETIME_MAX], v[I_START]


def list_pids():
    n = _libproc.proc_listallpids(None, 0)
    arr = (ctypes.c_int * (n + 64))()
    got = _libproc.proc_listallpids(arr, ctypes.sizeof(arr))
    return [p for p in arr[:got] if p > 0]


def ppid_of(pid):
    buf = ctypes.create_string_buffer(136)
    if _libproc.proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, buf, 136) != 136:
        return None
    return struct.unpack_from("<5I", buf, 0)[4]


def argv_of(pid):
    """Command line via KERN_PROCARGS2; falls back to `ps`. Empty string if unreadable."""
    try:
        size = ctypes.c_size_t(0)
        mib = (ctypes.c_int * 3)(1, 49, pid)
        if _libc.sysctl(mib, 3, None, ctypes.byref(size), None, 0) == 0 and size.value:
            buf = ctypes.create_string_buffer(size.value)
            if _libc.sysctl(mib, 3, buf, ctypes.byref(size), None, 0) == 0:
                raw = buf.raw[:size.value]
                argc = struct.unpack_from("<i", raw, 0)[0]
                parts = raw[4:].split(b"\0")
                parts = [p for p in parts if p]
                return " ".join(p.decode(errors="replace") for p in parts[:argc + 1])
    except Exception:
        pass
    try:
        return subprocess.run(["/bin/ps", "-o", "command=", "-p", str(pid)], capture_output=True,
                              text=True).stdout.strip()
    except OSError:
        return ""


def ps_fallback():
    """pid -> (ppid, rss_bytes) from one `ps` call; no footprint available."""
    out = subprocess.run(["/bin/ps", "-axo", "pid=,ppid=,rss="], capture_output=True, text=True).stdout
    res = {}
    for ln in out.splitlines():
        p = ln.split()
        if len(p) == 3 and all(x.isdigit() for x in p):
            res[int(p[0])] = (int(p[1]), int(p[2]) * 1024)
    return res


def load_classes(path=None):
    path = path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "classes.json")
    with open(path) as f:
        return json.load(f)["classes"]


def classify(argv, classes):
    for name, pats in classes:
        if any(p in argv for p in pats):
            return name
    return "other"


def sysctl_int(name):
    v = ctypes.c_int(0)
    sz = ctypes.c_size_t(4)
    if _libc.sysctlbyname(name.encode(), ctypes.byref(v), ctypes.byref(sz), None, 0) != 0:
        return None
    return v.value


def swap_usage():
    """(total, used) bytes from sysctl vm.swapusage (struct xsw_usage: 3 x u64, u32, bool)."""
    buf = ctypes.create_string_buffer(32)
    sz = ctypes.c_size_t(32)
    if _libc.sysctlbyname(b"vm.swapusage", buf, ctypes.byref(sz), None, 0) != 0:
        return None, None
    total, _avail, used = struct.unpack_from("<3Q", buf, 0)
    return total, used


def _host_swapouts():
    """vm_statistics64.swapouts via host_statistics64 (no fork). None if unavailable."""
    try:
        _libc.mach_host_self.restype = ctypes.c_uint32
        buf = ctypes.create_string_buffer(152)
        cnt = ctypes.c_uint32(38)  # HOST_VM_INFO64_COUNT
        if _libc.host_statistics64(_libc.mach_host_self(), 4, buf, ctypes.byref(cnt)) != 0:
            return None
        return struct.unpack_from("<Q", buf, 120)[0]
    except (AttributeError, OSError):
        return None


def swapouts():
    v = _host_swapouts()
    if v is not None:
        return v
    out = subprocess.run(["/usr/bin/vm_stat"], capture_output=True, text=True).stdout
    m = re.search(r"Swapouts:\s+(\d+)", out)
    return int(m.group(1)) if m else None


class Sampler:
    """Sample the process tree under `roots` (pids, or a callable returning pids) at `interval`.

    The tree is the roots plus all descendants. Row per pid per sample; the tree peak is the
    maximum over samples of the summed footprint.
    """

    def __init__(self, roots, out_dir, interval=0.25, sys_interval=1.0, classes=None,
                 group="bazel"):
        self.roots = roots
        self.out_dir = out_dir
        self.interval = interval
        self.sys_interval = sys_interval
        self.classes = classes if classes is not None else load_classes()
        self.group = group
        self.rows = []
        self.sys_rows = []
        self.tree = []  # (t, sum_footprint, sum_rss, n_pids)
        self._alive, self._roots_seen, self._tree = frozenset(), (), set()
        self.pp = {}     # pid -> ppid, evicted when the pid leaves the process table
        self.cls = {}    # pid -> class
        self.incarnation = {}  # pid -> start_abstime of the incarnation the caches belong to
        self.max_fp = {}
        self.cpu_by_thread = {}
        self.cpu_used = 0.0
        self.wall = 0.0
        self._stop = threading.Event()
        self._threads = []

    def _roots(self):
        return list(self.roots() if callable(self.roots) else self.roots)

    def sample_once(self, t0):
        pids = list_pids()
        alive = frozenset(pids)
        roots = tuple(self._roots())
        if alive != self._alive or roots != self._roots_seen or len(self.pp) != len(alive):
            # The process table or the roots changed: evict exited pids (macOS reuses pids),
            # learn the parents of new ones and rebuild the tree. Otherwise reuse last tick's tree.
            for cache in (self.pp, self.cls, self.incarnation, self.max_fp):
                for p in [p for p in cache if p not in alive]:
                    del cache[p]
            pp = self.pp
            kids = {}
            for p in pids:
                if p not in pp:
                    pp[p] = ppid_of(p)
                kids.setdefault(pp[p], []).append(p)
            tree, stack = set(), [r for r in roots if r in alive]
            while stack:
                p = stack.pop()
                if p in tree:
                    continue
                tree.add(p)
                stack.extend(kids.get(p, ()))
            self._alive, self._roots_seen, self._tree = alive, roots, tree
        tree = self._tree
        t = round(time.time() - t0, 3)
        fp_sum = rss_sum = 0
        rows = self.rows
        for p in tree:
            ru = rusage(p)
            if ru is None:
                continue
            fp, rss, cpu, lmax, start = ru
            if self.incarnation.get(p, start) != start:  # reused between two samples: new incarnation
                self.cls.pop(p, None)
                self.max_fp.pop(p, None)
                self.pp[p] = ppid_of(p)
            self.incarnation[p] = start
            if p not in self.cls:
                self.cls[p] = classify(argv_of(p), self.classes)
            self.max_fp[p] = max(self.max_fp.get(p, 0), lmax, fp)
            rows.append((t, p, self.pp.get(p), self.cls[p], fp, rss, cpu))
            fp_sum += fp
            rss_sum += rss
        self.tree.append((t, fp_sum, rss_sum, len(tree)))

    def _loop(self, t0):
        c0 = time.thread_time()
        nxt = time.time()
        while not self._stop.is_set():
            self.sample_once(t0)
            nxt += self.interval
            self._stop.wait(max(0.0, nxt - time.time()))
        self.cpu_by_thread["tree"] = time.thread_time() - c0

    def _sys_loop(self, t0):
        c0 = time.thread_time()
        nxt = time.time()
        while not self._stop.is_set():
            total, used = swap_usage()
            self.sys_rows.append((round(time.time() - t0, 3), used, swapouts(),
                                  sysctl_int("kern.memorystatus_vm_pressure_level")))
            nxt += self.sys_interval
            self._stop.wait(max(0.0, nxt - time.time()))
        self.cpu_by_thread["system"] = time.thread_time() - c0

    def start(self):
        self._t0 = time.time()
        for fn in (self._loop, self._sys_loop):
            th = threading.Thread(target=fn, args=(self._t0,), daemon=True)
            th.start()
            self._threads.append(th)
        return self

    def stop(self):
        self._stop.set()
        for th in self._threads:
            th.join()
        self.wall = time.time() - self._t0
        # CPU of the two sampler threads only (not RUSAGE_CHILDREN, not the caller's main thread).
        self.cpu_used = sum(self.cpu_by_thread.values())
        return self.write()

    def peaks(self):
        peak = max(self.tree, key=lambda r: r[1]) if self.tree else (0, 0, 0, 0)
        by_class = {}
        for _t, _p, _pp, c, fp, rss, _cpu in self.rows:
            d = by_class.setdefault(c, {"peak_footprint": 0, "peak_rss": 0})
            d["peak_footprint"] = max(d["peak_footprint"], fp)
            d["peak_rss"] = max(d["peak_rss"], rss)
        return {
            "group": self.group,
            "samples": len(self.tree),
            "tree_peak_footprint": peak[1],
            "tree_peak_footprint_t": peak[0],
            "tree_peak_rss_at_peak": peak[2],
            "tree_peak_rss": max((r[2] for r in self.tree), default=0),
            "first_sample_footprint": self.tree[0][1] if self.tree else 0,
            "max_pids": max((r[3] for r in self.tree), default=0),
            "by_class": by_class,
            "sampler_cpu_fraction": (self.cpu_used / self.wall) if self.wall else None,
            "interval_s": self.interval,
        }

    def write(self):
        os.makedirs(self.out_dir, exist_ok=True)
        with gzip.open(os.path.join(self.out_dir, "samples.csv.gz"), "wt", newline="") as f:
            w = csv.writer(f)
            w.writerow(["t", "pid", "ppid", "class", "footprint", "rss", "cpu_s"])
            w.writerows((round(r[0], 3),) + r[1:6] + (round(r[6], 4),) for r in self.rows)
        with open(os.path.join(self.out_dir, "system.csv"), "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["t", "swap_used", "swapouts", "pressure_level"])
            w.writerows(self.sys_rows)
        pk = self.peaks()
        with open(os.path.join(self.out_dir, "peaks.json"), "w") as f:
            json.dump(pk, f, indent=2)
        return pk


def main(argv):
    """sampler.py PID OUT_DIR [SECONDS]: sample PID's tree until it exits (or SECONDS)."""
    pid, out = int(argv[1]), argv[2]
    limit = float(argv[3]) if len(argv) > 3 else None
    s = Sampler([pid], out).start()
    t0 = time.time()
    while rusage(pid) and (limit is None or time.time() - t0 < limit):
        time.sleep(0.2)
    print(json.dumps(s.stop(), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
