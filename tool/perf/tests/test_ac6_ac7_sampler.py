import csv
import os
import subprocess
import sys
import tempfile
import time
import unittest

import helpers  # noqa: F401
import sampler

MIB = 1 << 20
GIB = 1 << 30

CHILD = """
import sys,time
n=512*1024*1024
b=bytearray(n)
for i in range(0,n,4096): b[i]=1
sys.stdout.write("x\\n"); sys.stdout.flush()
time.sleep(float(sys.argv[1]))
"""

PARENT = """
import subprocess,sys,time
kids=[subprocess.Popen([sys.executable,"-I","-c",%r,"2.5"],stdout=subprocess.PIPE) for _ in range(3)]
for k in kids: k.stdout.readline()
time.sleep(1.5)
for k in kids: k.wait()
""" % CHILD


class MemorySamplerTest(unittest.TestCase):
    def test_T_0016_AC6_three_children_512MiB_tree_peak(self):
        out = tempfile.mkdtemp(prefix="mc-t0016-samp-")
        # Parent idles for a moment first so the baseline sample is the parent alone.
        parent = subprocess.Popen([sys.executable, "-I", "-c", "import time;time.sleep(1.0)\n" + PARENT])
        s = sampler.Sampler([parent.pid], out, interval=0.25).start()
        parent.wait()
        pk = s.stop()
        baseline = pk["first_sample_footprint"]
        delta = pk["tree_peak_footprint"] - baseline
        # 1.5 GiB + baseline +-10 %; the 3 interpreters add a few MiB each on top of the 1.5 GiB.
        expected = 1.5 * GIB
        self.assertGreater(delta, expected * 0.9, pk)
        self.assertLess(delta, expected * 1.1, pk)
        self.assertGreater(pk["tree_peak_rss"], 0)
        self.assertIn("tree_peak_rss_at_peak", pk)
        self.assertGreaterEqual(pk["max_pids"], 4)
        self.assertTrue(os.path.exists(os.path.join(out, "samples.csv.gz")))
        self.assertTrue(os.path.exists(os.path.join(out, "peaks.json")))


class CacheTest(unittest.TestCase):
    def test_T_0016_AC6_exited_pids_are_evicted_and_reused_pid_is_reclassified(self):
        child = subprocess.Popen(["/bin/sleep", "20"])
        self.addCleanup(lambda: (child.kill(), child.wait()))
        s = sampler.Sampler([child.pid], tempfile.mkdtemp(prefix="mc-t0016-c-"))
        s.sample_once(time.time())
        self.assertIn(child.pid, s.cls)
        s.cls[child.pid] = "stale"
        s.incarnation[child.pid] = 1  # pretend the cache belongs to an earlier incarnation of this pid
        s.pp[999999] = 1
        s.cls[999999] = "ghost"
        s.sample_once(time.time())
        self.assertNotEqual(s.cls[child.pid], "stale")
        self.assertNotIn(999999, s.cls)
        self.assertNotIn(999999, s.pp)

    def test_T_0016_AC6_rusage_is_thread_safe(self):
        import threading
        a = subprocess.Popen(["/bin/sleep", "20"])
        b = subprocess.Popen(["/bin/sleep", "20"])
        self.addCleanup(lambda: [(p.kill(), p.wait()) for p in (a, b)])
        want = {p.pid: sampler.rusage(p.pid)[4] for p in (a, b)}
        bad = []

        def work(pid):
            for _ in range(3000):
                r = sampler.rusage(pid)
                if r is None or r[4] != want[pid]:
                    bad.append(pid)
        ths = [threading.Thread(target=work, args=(p.pid,)) for p in (a, b) * 4]
        [t.start() for t in ths]
        [t.join() for t in ths]
        self.assertEqual(bad, [])


class OverheadTest(unittest.TestCase):
    def test_T_0016_AC7_overhead_counts_sampler_threads_only(self):
        child = subprocess.Popen(["/bin/sleep", "20"])
        self.addCleanup(lambda: (child.kill(), child.wait()))
        s = sampler.Sampler([child.pid], tempfile.mkdtemp(prefix="mc-t0016-o-")).start()
        t_end = time.time() + 2.0
        while time.time() < t_end:  # burn CPU on the main thread, plus a child process
            sum(range(10000))
        subprocess.run(["/usr/bin/python3", "-c", "sum(range(5000000))"])
        pk = s.stop()
        self.assertLess(pk["sampler_cpu_fraction"], 0.02, pk)

    def test_T_0016_AC7_200_pids_at_250ms_overhead_under_2_percent(self):
        sleepers = [subprocess.Popen(["/bin/sleep", "30"]) for _ in range(200)]
        self.addCleanup(lambda: [(p.kill(), p.wait()) for p in sleepers])
        root = subprocess.Popen(["/bin/sh", "-c", "sleep 30 & sleep 30"])  # a real parent
        self.addCleanup(lambda: (root.kill(), root.wait()))
        out = tempfile.mkdtemp(prefix="mc-t0016-ovh-")
        s = sampler.Sampler(lambda: [p.pid for p in sleepers] + [root.pid], out,
                            interval=0.25, sys_interval=1.0).start()
        time.sleep(8)
        pk = s.stop()
        self.assertGreaterEqual(pk["max_pids"], 200)
        self.assertLessEqual(pk["sampler_cpu_fraction"], 0.02, pk)
        # system series at 1 s
        with open(os.path.join(out, "system.csv")) as f:
            rows = list(csv.DictReader(f))
        self.assertGreaterEqual(len(rows), 7)
        ts = [float(r["t"]) for r in rows]
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        self.assertTrue(all(0.8 < g < 1.3 for g in gaps), gaps)
        for col in ("swap_used", "swapouts", "pressure_level"):
            self.assertNotEqual(rows[0][col], "", col)
        # the process tree series ran at ~250 ms
        self.assertGreaterEqual(pk["samples"], 28)


if __name__ == "__main__":
    unittest.main()
