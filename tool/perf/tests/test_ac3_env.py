import json
import subprocess
import sys
import os
import unittest

import helpers  # noqa: F401
import env

REQUIRED = ["repo_sha", "bazel", "flutter", "dart", "xcode", "macos", "machine_id", "power_source",
            "thermal_state", "profile", "bench_version"]


class EnvTest(unittest.TestCase):
    def test_T_0016_AC3_env_json_has_all_fields(self):
        p = subprocess.run([sys.executable, "-I", os.path.join(helpers.PERF, "bench.py"), "env",
                            helpers.PERF], capture_output=True, text=True, timeout=120)
        self.assertEqual(p.returncode, 0, p.stderr)
        d = json.loads(p.stdout)
        for k in REQUIRED:
            self.assertIn(k, d)
        self.assertRegex(d["repo_sha"], r"^[0-9a-f]{40}$")
        self.assertTrue(d["bazel"].startswith("bazel"))
        self.assertEqual(d["bench_version"], env.BENCH_VERSION)

    def test_T_0016_AC3_power_and_thermal_parsing(self):
        self.assertEqual(env.power_source("Now drawing from 'AC Power'"), "ac")
        self.assertEqual(env.power_source("Now drawing from 'Battery Power'"), "battery")
        self.assertEqual(env.thermal_state("CPU_Scheduler_Limit = 100\nCPU_Speed_Limit = 100"),
                         "nominal")
        self.assertEqual(env.thermal_state("CPU_Speed_Limit = 70"), "limited:70")

    def test_T_0016_AC3_drift_above_5_percent_flags_machine_drift(self):
        ref = {"s0_null": 1.00, "kernel": 10.0}
        ok = env.machine_drift(ref, {"s0_null": 1.04, "kernel": 10.4})
        self.assertFalse(ok["machine_drift"])
        bad = env.machine_drift(ref, {"s0_null": 1.00, "kernel": 10.6})
        self.assertTrue(bad["machine_drift"])
        self.assertEqual(list(bad["drifted"]), ["kernel"])

    def test_T_0016_AC3_capture_records_drift(self):
        d = env.capture(helpers.PERF, calibration={"a": 1.2}, reference={"a": 1.0})
        self.assertTrue(d["machine_drift"])


if __name__ == "__main__":
    unittest.main()
