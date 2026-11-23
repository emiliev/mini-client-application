import os
import subprocess
import sys
import unittest

import helpers  # noqa: F401  (sets sys.path)
import flags

BENCH = os.path.join(helpers.PERF, "bench.py")


class FlagsTest(unittest.TestCase):
    def test_T_0016_AC1_parse_help_handles_no_prefix(self):
        names = flags.parse_help("  --[no]slim_profile (a boolean)\n  --profile (a path)\n")
        self.assertTrue({"slim_profile", "noslim_profile", "profile"} <= names)

    def test_T_0016_AC1_inventory_covers_profiles_and_plan(self):
        inv = set(flags.inventory())
        self.assertIn(("build", "experimental_total_worker_memory_limit_mb"), inv)  # profile rc
        self.assertIn(("build", "starlark_cpu_profile"), inv)  # plan 6.3
        self.assertIn(("startup", "host_jvm_args"), inv)

    def test_T_0016_AC1_missing_flag_is_reported_by_name_with_stub_help(self):
        helps = {"startup_options": "  --host_jvm_args (x)\n", "build": "  --profile (x)\n"}
        res = flags.check("bazel", ".", extra=[("build", "no_such_flag")],
                          help_fn=lambda t: helps[t])
        self.assertIn("build:no_such_flag", res["missing"])
        self.assertIn("build:profile", res["available"])
        self.assertIn("startup:host_jvm_args", res["available"])

    def test_T_0016_AC1_failed_bazel_help_raises_instead_of_reporting_all_missing(self):
        with self.assertRaises(RuntimeError):
            flags.bazel_help("/usr/bin/false", "build", ".")

    def test_T_0016_AC1_help_output_base_is_per_process(self):
        self.assertIn(str(os.getpid()), flags.cwd_output_base())

    def test_T_0016_AC1_real_bazel_every_flag_classified_and_bogus_fails_by_name(self):
        p = subprocess.run([sys.executable, "-I", BENCH, "flags", "--extra", "build:bogus_flag_xyz"],
                           capture_output=True, text=True, timeout=600)
        self.assertEqual(p.returncode, 1)
        self.assertIn("MISSING    build:bogus_flag_xyz", p.stdout)
        self.assertIn("build:bogus_flag_xyz", p.stderr)
        n = len(flags.inventory()) + 1
        lines = [x for x in p.stdout.splitlines() if x.startswith(("available", "MISSING"))]
        self.assertEqual(len(lines), n)


if __name__ == "__main__":
    unittest.main()
