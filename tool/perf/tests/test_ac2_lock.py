"""Intruder detection reads the process table only; these tests mock it and never touch a real
simulator or Bazel server."""
import os
import tempfile
import unittest

import helpers  # noqa: F401
import lock
import bench

SIM = (900, 1, "/Library/Developer/CoreSimulator/launchd_sim /x/data")
BZL = (901, 1, "java -jar /x/install/A-server.jar --foo")
IDLE = (5, 1, "/bin/sleep 1")


def quiet(**kw):
    kw.setdefault("load_fn", lambda: 0.0)
    return kw


class LockTest(unittest.TestCase):
    def setUp(self):
        self.path = os.path.join(tempfile.mkdtemp(prefix="mc-t0016-lock-"), "lock")

    def test_T_0016_AC2_second_holder_is_refused(self):
        with lock.PerfLock(self.path, procs_fn=lambda: [IDLE], **quiet()):
            with self.assertRaises(lock.LockBusy) as cm:
                lock.PerfLock(self.path, procs_fn=lambda: [IDLE], **quiet()).__enter__()
            self.assertIn("held by another run", str(cm.exception))
        with lock.PerfLock(self.path, procs_fn=lambda: [IDLE], **quiet()):
            pass  # released on exit

    def test_T_0016_AC2_foreign_bazel_server_refuses(self):
        with self.assertRaises(lock.LockBusy) as cm:
            lock.PerfLock(self.path, procs_fn=lambda: [IDLE, BZL], **quiet()).__enter__()
        self.assertIn("bazel-server", str(cm.exception))

    def test_T_0016_AC2_own_server_is_not_an_intruder(self):
        with lock.PerfLock(self.path, procs_fn=lambda: [BZL], own_server_pids=[901], **quiet()):
            pass

    def test_T_0016_AC2_booted_simulator_refuses(self):
        with self.assertRaises(lock.LockBusy) as cm:
            lock.PerfLock(self.path, procs_fn=lambda: [SIM], **quiet()).__enter__()
        self.assertIn("simulator", str(cm.exception))

    def test_T_0016_AC2_high_load_refuses(self):
        with self.assertRaises(lock.LockBusy):
            lock.PerfLock(self.path, procs_fn=lambda: [], load_fn=lambda: 5.0).__enter__()

    def test_T_0016_AC2_failed_start_releases_lock(self):
        with self.assertRaises(lock.LockBusy):
            lock.PerfLock(self.path, procs_fn=lambda: [SIM], **quiet()).__enter__()
        with lock.PerfLock(self.path, procs_fn=lambda: [], **quiet()):
            pass

    def test_T_0016_AC2_mid_run_intruder_marks_contaminated(self):
        calls = {"n": 0}

        def procs():
            calls["n"] += 1
            return [IDLE] if calls["n"] == 1 else [IDLE, SIM]

        out = tempfile.mkdtemp(prefix="mc-t0016-run-")
        s = bench.run_timed(["/bin/sleep", "1"], out, helpers.PERF, poll=0.2,
                            lock_kwargs=dict(path=self.path, procs_fn=procs, **quiet()))
        self.assertTrue(s["contaminated"])
        self.assertEqual(s["exit"], 0)
        self.assertTrue(os.path.exists(os.path.join(out, "env.json")))

    def test_T_0016_AC2_own_output_base_server_is_not_an_intruder(self):
        ob = tempfile.mkdtemp(prefix="mc-t0016-ob-")
        os.makedirs(os.path.join(ob, "server"))
        with open(os.path.join(ob, "server", "server.pid.txt"), "w") as f:
            f.write("4242")
        self.assertEqual(lock.server_pid(ob), 4242)
        own = (4242, 1, "java -jar /x/A-server.jar --output_base=%s --foo" % ob)
        by_argv = (4243, 1, "java -jar /x/A-server.jar --output_base=%s --foo" % ob)
        foreign = (4244, 1, "java -jar /x/A-server.jar --output_base=%s-other --foo" % ob)
        self.assertEqual(lock.find_intruders([own], own_server_pids=[4242]), [])
        self.assertEqual(lock.find_intruders([by_argv], own_output_bases=[ob]), [])
        self.assertEqual(len(lock.find_intruders([foreign], own_output_bases=[ob])), 1)
        out = tempfile.mkdtemp(prefix="mc-t0016-run-")
        s = bench.run_timed(["/bin/sleep", "0.6"], out, helpers.PERF, poll=0.1, output_base=ob,
                            lock_kwargs=dict(path=self.path, procs_fn=lambda: [IDLE, own], **quiet()))
        self.assertFalse(s["contaminated"], s)

    def test_T_0016_AC2_foreign_server_mid_run_still_contaminates_with_output_base(self):
        ob = tempfile.mkdtemp(prefix="mc-t0016-ob-")
        calls = {"n": 0}

        def procs():
            calls["n"] += 1
            return [IDLE] if calls["n"] == 1 else [IDLE, BZL]

        s = bench.run_timed(["/bin/sleep", "0.8"], tempfile.mkdtemp(prefix="mc-t0016-run-"),
                            helpers.PERF, poll=0.1, output_base=ob,
                            lock_kwargs=dict(path=self.path, procs_fn=procs, **quiet()))
        self.assertTrue(s["contaminated"])

    def test_T_0016_AC2_run_strips_only_the_leading_separator(self):
        self.assertEqual(bench.strip_separator(["--", "bazel", "build", "--", "//x"]),
                         ["bazel", "build", "--", "//x"])
        self.assertEqual(bench.strip_separator(["echo", "--"]), ["echo", "--"])

    def test_T_0016_AC2_parses_real_ps_output_fixture(self):
        fx = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "ps_axo.txt")
        with open(fx) as f:
            procs = lock.parse_ps(f.read())
        self.assertGreater(len(procs), 50)
        self.assertEqual(procs[0][:2], (1, 0))
        kinds = sorted(i["kind"] for i in lock.find_intruders(procs))
        self.assertEqual(kinds, ["bazel-server", "simulator"])
        live = lock.list_processes()  # same format from the live `ps`
        self.assertTrue(any(p[0] == os.getpid() for p in live))

    def test_T_0016_AC2_clean_run_not_contaminated(self):
        out = tempfile.mkdtemp(prefix="mc-t0016-run-")
        s = bench.run_timed(["/bin/sleep", "0.3"], out, helpers.PERF, poll=0.1,
                            lock_kwargs=dict(path=self.path, procs_fn=lambda: [IDLE], **quiet()))
        self.assertFalse(s["contaminated"])


if __name__ == "__main__":
    unittest.main()
