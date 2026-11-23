import io
import json
import os
import subprocess
import sys
import tempfile
import unittest

import helpers
import execlog


class StreamTest(unittest.TestCase):
    def test_T_0016_AC4_reader_handles_pretty_printed_concatenated_objects_across_chunks(self):
        objs = [{"a": i, "s": "x" * 50, "n": {"k": [1, 2, 3]}} for i in range(200)]
        text = "".join(json.dumps(o, indent=2) for o in objs)
        got = list(execlog.iter_json_objects(io.StringIO(text), chunk=37))
        self.assertEqual(got, objs)

    def test_T_0016_AC4_reader_handles_newline_delimited(self):
        text = "\n".join(json.dumps({"i": i}) for i in range(5)) + "\n"
        self.assertEqual(len(list(execlog.iter_json_objects(io.StringIO(text), chunk=4))), 5)

    def test_T_0016_AC4_diff_pairs_and_reports_changed_inputs(self):
        def rec(h):
            return {"inputs": h, "label": "", "runner": "", "cache_hit": False, "wall": "",
                    "n_inputs": 1}
        a = {"G|x": rec("1"), "G|y": rec("2"), "G|gone": rec("3")}
        b = {"G|x": rec("1"), "G|y": rec("9"), "G|new": rec("4")}
        d = execlog.diff(a, b)
        self.assertEqual(d["paired"], 2)
        self.assertEqual(d["changed"], ["G|y"])
        self.assertEqual(d["only_in_a"], ["G|gone"])
        self.assertEqual(d["only_in_b"], ["G|new"])

    def test_T_0016_AC4_key_collisions_are_kept_and_reported(self):
        d = tempfile.mkdtemp(prefix="mc-t0016-col-")
        p = os.path.join(d, "l.json")

        def sp(h):
            return {"mnemonic": "G", "targetLabel": "//:t", "listedOutputs": [],
                    "inputs": [{"path": "i", "digest": {"hash": h}}]}
        with open(p, "w") as f:
            f.write(json.dumps(sp("1"), indent=2) + json.dumps(sp("2"), indent=2))
        col = []
        s = execlog.summarize(p, collisions=col)
        self.assertEqual(len(s), 2)  # nothing overwritten
        self.assertEqual(col, ["G|//:t|"])
        self.assertNotEqual(list(s.values())[0]["inputs"], list(s.values())[1]["inputs"])

    def test_T_0016_AC4_key_includes_target_label(self):
        a = {"mnemonic": "G", "targetLabel": "//:a", "listedOutputs": []}
        b = {"mnemonic": "G", "targetLabel": "//:b", "listedOutputs": []}
        self.assertNotEqual(execlog.spawn_key(a), execlog.spawn_key(b))

    def test_T_0016_AC4_workspace_copy_skips_bazel_symlinks_and_none_are_tracked(self):
        src = tempfile.mkdtemp(prefix="mc-t0016-src-")
        os.makedirs(src + "/ws_in", exist_ok=True)
        shutil_src = os.path.join(src, "ws")
        import shutil
        shutil.copytree(helpers.WS_SRC, shutil_src)
        os.symlink("/nonexistent/mc-t0016", os.path.join(shutil_src, "bazel-out"))
        w = helpers.BazelWs(src=shutil_src)
        self.addCleanup(w.close)
        self.assertFalse(any(n.startswith("bazel-") for n in os.listdir(w.ws)))
        tracked = subprocess.run(["git", "ls-files", "-s", "--", helpers.WS_SRC],
                                 capture_output=True, text=True, cwd=helpers.PERF).stdout
        self.assertNotIn("120000", tracked)  # no tracked symlinks in the test workspace

    def test_T_0016_AC4_peak_rss_bounded_on_synthetic_large_log(self):
        d = tempfile.mkdtemp(prefix="mc-t0016-big-")
        path = os.path.join(d, "big.json")
        n = 50000
        with open(path, "w") as f:
            for i in range(n):
                sp = {"commandArgs": ["/bin/cc", "-o", "out%d" % i] + ["-DFLAG=%d" % j for j in range(8)],
                      "environmentVariables": [{"name": "PATH", "value": "/bin:/usr/bin"}],
                      "inputs": [{"path": "in/%d_%d.c" % (i, j),
                                  "digest": {"hash": "%064x" % (i * 31 + j), "sizeBytes": "99"}}
                                 for j in range(6)],
                      "listedOutputs": ["bazel-out/out%d" % i], "mnemonic": "CppCompile",
                      "runner": "darwin-sandbox", "targetLabel": "//p:t%d" % i,
                      "metrics": {"executionWallTime": "0.01s"}}
                f.write(json.dumps(sp, indent=2))
        size = os.path.getsize(path)
        self.assertGreater(size, 50 * 1024 * 1024)
        code = ("import sys,resource; sys.path.insert(0,%r); import execlog; "
                "s=execlog.summarize(%r); print(len(s), resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)"
                % (helpers.PERF, path))
        out = subprocess.run([sys.executable, "-I", "-c", code], capture_output=True, text=True,
                             timeout=300)
        self.assertEqual(out.returncode, 0, out.stderr)
        count, maxrss = map(int, out.stdout.split())
        self.assertEqual(count, n)
        # macOS reports bytes. Bounded: well under the file size and under 200 MiB.
        self.assertLess(maxrss, 200 * 1024 * 1024)
        self.assertLess(maxrss, size)
        os.remove(path)


class RealBazelTest(unittest.TestCase):
    def test_T_0016_AC4_two_real_logs_one_input_edited(self):
        w = helpers.BazelWs()
        self.addCleanup(w.close)
        d = tempfile.mkdtemp(prefix="mc-t0016-logs-")
        la, lb = os.path.join(d, "a.json"), os.path.join(d, "b.json")
        w.bazel("build", "//:out_ab", "--execution_log_json_file=" + la)
        w.write("a.txt", "in-a edited\n")
        w.bazel("clean")
        w.bazel("build", "//:out_ab", "--execution_log_json_file=" + lb)
        sa, sb = execlog.summarize(la), execlog.summarize(lb)
        self.assertEqual(len(sa), 3)
        self.assertEqual(len(sb), 3)
        r = execlog.diff(sa, sb)
        self.assertEqual(r["paired"], 3)
        self.assertEqual(r["only_in_a"], [])
        self.assertEqual(r["only_in_b"], [])
        # a.txt feeds out_a; out_a feeds out_ab; out_b is untouched.
        self.assertEqual(r["changed_labels"], ["//:out_a", "//:out_ab"])


if __name__ == "__main__":
    unittest.main()
