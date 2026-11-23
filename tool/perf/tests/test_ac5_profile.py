import json
import os
import subprocess
import tempfile
import unittest

import helpers
import traceprof


def fixture():
    ev = [
        {"cat": "build phase marker", "name": "Launch Blaze", "ph": "X", "ts": -11000, "dur": 11000},
        {"cat": "build phase marker", "name": "Initialize command", "ph": "i", "ts": 0},
        {"cat": "build phase marker", "name": "Evaluate target patterns", "ph": "i", "ts": 1000},
        {"cat": "build phase marker", "name": "Load, analyze dependencies and build artifacts",
         "ph": "i", "ts": 5000},
        {"cat": "build phase marker", "name": "Complete build", "ph": "i", "ts": 20000},
        {"cat": "action processing", "name": "x", "ph": "X", "ts": 6000, "dur": 24000},
    ]
    return {"traceEvents": ev}


class ProfileTest(unittest.TestCase):
    def test_T_0016_AC5_phase_totals_exact_on_fixture(self):
        t = traceprof.phase_totals(fixture())
        self.assertEqual(t["Initialize command"], 1.0)
        self.assertEqual(t["Evaluate target patterns"], 4.0)
        self.assertEqual(t["Load, analyze dependencies and build artifacts"], 15.0)
        self.assertEqual(t["Complete build"], 10.0)

    def test_T_0016_AC5_bep_units_ms_fields_not_scaled_durations_converted(self):
        d = tempfile.mkdtemp(prefix="mc-t0016-bep-")
        p = os.path.join(d, "bep.json")
        with open(p, "w") as f:
            f.write('{"id":{}}\n')
            f.write(json.dumps({"buildMetrics": {"timingMetrics": {
                "wallTimeInMs": "1234", "cpuTimeInMs": "56", "criticalPathTime": "0.5s"}}}) + "\n")
        t = traceprof.bep_timing(p)
        self.assertEqual(t["wallTimeInMs"], 1234.0)
        self.assertEqual(t["cpuTimeInMs"], 56.0)
        self.assertEqual(t["criticalPathTime"], 500.0)

    def test_T_0016_AC5_within_one_percent_comparator(self):
        ref = {"a": 100.0}
        self.assertTrue(traceprof.within({"a": 100.9}, ref))
        self.assertFalse(traceprof.within({"a": 102.0}, ref))

    def test_T_0016_AC5_analyze_profile_output_parser(self):
        txt = "=== PHASE SUMMARY INFORMATION ===\n\nInitialize command   0.001 s  5.00 %\n"
        self.assertEqual(traceprof.parse_analyze_profile(txt), {"Initialize command": 1.0})

    def test_T_0016_AC5_real_trace_phases_cover_profile_and_match_bep_wall(self):
        w = helpers.BazelWs()
        self.addCleanup(w.close)
        d = tempfile.mkdtemp(prefix="mc-t0016-prof-")
        prof, bep = os.path.join(d, "p.json.gz"), os.path.join(d, "bep.json")
        w.bazel("build", "//:out_ab", "--profile=" + prof, "--noslim_profile",
                "--build_event_json_file=" + bep)
        t = traceprof.phase_totals(traceprof.load_trace(prof))
        for name in ("Initialize command", "Evaluate target patterns", "Complete build"):
            self.assertIn(name, t)
        self.assertTrue(all(v >= 0 for v in t.values()))
        timing = traceprof.bep_timing(bep)
        self.assertIn("wallTimeInMs", timing)
        # Measured: the phases sum to BEP wall time within 0.03 %; allow 1 % so it can still fail.
        wall = timing["wallTimeInMs"]
        self.assertLess(abs(sum(t.values()) - wall) / wall, 0.01, (t, timing))

    def test_T_0016_AC5_matches_bazel_analyze_profile_within_1_percent(self):
        w = helpers.BazelWs()
        self.addCleanup(w.close)
        h = subprocess.run(["bazel", "--output_base=" + w.obase, "help"], cwd=w.ws,
                           capture_output=True, text=True).stdout
        if not traceprof.analyze_profile_available(h):
            self.skipTest("DEFERRED: Bazel 9.2.0 has no `analyze-profile` command (removed); "
                          "AC5 reference comparison cannot run. See T-0016 Outcome.")
        d = tempfile.mkdtemp(prefix="mc-t0016-prof-")
        prof = os.path.join(d, "p.json.gz")
        w.bazel("build", "//:out_ab", "--profile=" + prof, "--noslim_profile")
        ref = traceprof.parse_analyze_profile(w.bazel("analyze-profile", prof).stdout)
        self.assertTrue(traceprof.within(traceprof.phase_totals(traceprof.load_trace(prof)), ref))


if __name__ == "__main__":
    unittest.main()
