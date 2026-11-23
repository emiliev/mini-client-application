"""Test helpers: path setup plus a throwaway Bazel workspace with its own output base under /tmp."""
import os
import shutil
import subprocess
import sys
import tempfile

PERF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PERF not in sys.path:
    sys.path.insert(0, PERF)

WS_SRC = os.path.join(PERF, "testdata", "genrule_ws")


class BazelWs:
    """Copy of the genrule workspace. Always call close() (it runs `bazel shutdown`)."""

    def __init__(self, src=WS_SRC):
        self.root = tempfile.mkdtemp(prefix="mc-t0016-ws-", dir="/tmp")
        self.ws = os.path.join(self.root, "ws")
        self.obase = os.path.join(self.root, "obase")
        shutil.copytree(src, self.ws, ignore=shutil.ignore_patterns("bazel-*"))

    def bazel(self, *args):
        r = subprocess.run(["bazel", "--output_base=" + self.obase] + list(args), cwd=self.ws,
                           capture_output=True, text=True, timeout=600)
        if r.returncode != 0:
            raise RuntimeError("bazel %s failed: %s" % (args, r.stderr[-2000:]))
        return r

    def write(self, name, text):
        with open(os.path.join(self.ws, name), "w") as f:
            f.write(text)

    def close(self):
        try:
            subprocess.run(["bazel", "--output_base=" + self.obase, "shutdown"], cwd=self.ws,
                           capture_output=True, timeout=120)
        finally:
            shutil.rmtree(self.root, ignore_errors=True)
