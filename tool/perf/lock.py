"""Machine-wide perf lock and intruder detection (T-0016 AC2, plan 04 KD-4 / C-1).

The lock is `/tmp/mc-perf.lock`, taken with flock plus a JSON owner record. Intruder detection only
reads the process table: it never boots, shuts down or kills a simulator or a Bazel server.
"""
import fcntl
import json
import os
import subprocess
import sys
import time

LOCK_PATH = "/tmp/mc-perf.lock"


class LockBusy(Exception):
    pass


class Contaminated(Exception):
    pass


def list_processes():
    """[(pid, ppid, command)] from one `ps` call."""
    out = subprocess.run(["/bin/ps", "-axo", "pid=,ppid=,command="], capture_output=True,
                         text=True).stdout
    return parse_ps(out)


def parse_ps(out):
    """Parse `ps -axo pid=,ppid=,command=` text into [(pid, ppid, command)]."""
    procs = []
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
            procs.append((int(parts[0]), int(parts[1]), parts[2]))
    return procs


def server_pid(output_base):
    """pid of the Bazel server that owns `output_base`, from server/server.pid.txt (or None)."""
    try:
        with open(os.path.join(output_base, "server", "server.pid.txt")) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None


def find_intruders(procs, own_server_pids=(), own_pids=(), own_output_bases=()):
    """Foreign Bazel servers and booted-simulator processes.

    A Bazel server is a java process whose argv carries `A-server.jar`; ours are excluded via
    own_server_pids or by `--output_base=<own base>` on its argv. A booted Simulator shows as a `launchd_sim` process.
    """
    own = set(own_server_pids) | set(own_pids)
    found = []
    for pid, _ppid, cmd in procs:
        if pid in own:
            continue
        if "A-server.jar" in cmd:
            if any(("--output_base=" + ob + " ") in (cmd + " ") for ob in own_output_bases):
                continue
            found.append({"pid": pid, "kind": "bazel-server", "cmd": cmd[:120]})
        elif "launchd_sim" in cmd:
            found.append({"pid": pid, "kind": "simulator", "cmd": cmd[:120]})
    return found


def load_average():
    return os.getloadavg()[0]


class PerfLock:
    """Context manager. `refuse` conditions raise LockBusy before the run starts; `check()` called
    during a run records contamination instead of raising."""

    def __init__(self, path=LOCK_PATH, procs_fn=list_processes, own_server_pids=(),
                 max_load=2.0, load_fn=load_average, own_output_bases=()):
        self.path = path
        self.procs_fn = procs_fn
        self.own_server_pids = own_server_pids  # iterable or callable, re-read on every poll
        self.own_output_bases = list(own_output_bases) + [os.path.realpath(b) for b in own_output_bases]
        self.max_load = max_load
        self.load_fn = load_fn
        self.fd = None
        self.contaminated = False
        self.events = []

    def _own_pids(self):
        v = self.own_server_pids
        return set(v() if callable(v) else v)

    def __enter__(self):
        self.fd = os.open(self.path, os.O_RDWR | os.O_CREAT, 0o644)
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            holder = os.pread(self.fd, 4096, 0).decode(errors="replace")
            os.close(self.fd)
            self.fd = None
            raise LockBusy("perf lock %s is held by another run: %s" % (self.path, holder))
        intruders = find_intruders(self.procs_fn(), self._own_pids(), (), self.own_output_bases)
        if intruders or self.load_fn() >= self.max_load:
            self._release()
            if intruders:
                raise LockBusy("refusing to start: intruders present: %s" % json.dumps(intruders))
            raise LockBusy("refusing to start: load average >= %s" % self.max_load)
        os.ftruncate(self.fd, 0)
        os.pwrite(self.fd, json.dumps({"pid": os.getpid(), "started": time.time()}).encode(), 0)
        return self

    def check(self):
        """Poll for intruders mid-run. Returns the new intruders and marks the run contaminated."""
        intruders = find_intruders(self.procs_fn(), self._own_pids(), (), self.own_output_bases)
        if intruders:
            self.contaminated = True
            self.events.append({"t": time.time(), "intruders": intruders})
        return intruders

    def _release(self):
        if self.fd is not None:
            try:
                fcntl.flock(self.fd, fcntl.LOCK_UN)
            finally:
                os.close(self.fd)
                self.fd = None

    def __exit__(self, *exc):
        self._release()
        return False


if __name__ == "__main__":
    print(json.dumps(find_intruders(list_processes()), indent=2))
    sys.exit(0)
