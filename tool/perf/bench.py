"""Perf harness entry point. Run as `python3 -I tool/perf/bench.py <command>`.

Commands:
  flags [--bazel B] [--cwd WS] [--extra kind:flag ...]   AC1: flag inventory; exit 1 if any missing
  env [REPO]                                             print env.json
  run --out DIR -- CMD...                                timed-run wrapper skeleton (lock, env,
                                                         sampler, contamination check)
"""
import argparse
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import env as envmod  # noqa: E402
import flags as flagsmod  # noqa: E402
import lock as lockmod  # noqa: E402

DEFAULT_WS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testdata", "genrule_ws")


def cmd_flags(args):
    extra = []
    for e in args.extra or []:
        kind, _, name = e.partition(":")
        extra.append((kind, name))
    try:
        res = flagsmod.check(args.bazel, args.cwd, extra)
    finally:
        flagsmod.shutdown(args.bazel, args.cwd)
    for f in res["available"]:
        print("available  " + f)
    for f in res["missing"]:
        print("MISSING    " + f)
    if res["missing"]:
        print("FAIL: %d flag(s) missing: %s" % (len(res["missing"]), ", ".join(res["missing"])),
              file=sys.stderr)
        return 1
    return 0


def run_timed(argv, out_dir, repo, lock_kwargs=None, poll=1.0, profile="none", output_base=None):
    """Skeleton of a timed run. Refuses (LockBusy) on a held lock or intruders; marks the run
    contaminated if an intruder appears while `argv` runs. Returns the run summary dict."""
    os.makedirs(out_dir, exist_ok=True)
    kw = dict(lock_kwargs or {})
    if output_base:
        # The measured run's own server is not an intruder (match by pid file and by argv).
        kw["own_output_bases"] = list(kw.get("own_output_bases", [])) + [output_base]
        kw["own_server_pids"] = lambda: [p for p in [lockmod.server_pid(output_base)] if p]
    with lockmod.PerfLock(**kw) as lk:
        with open(os.path.join(out_dir, "env.json"), "w") as f:
            json.dump(envmod.capture(repo, profile=profile), f, indent=2)
        t0 = time.time()
        p = subprocess.Popen(argv)
        while p.poll() is None:
            lk.check()
            time.sleep(poll)
        summary = {"argv": argv, "exit": p.returncode, "wall_s": round(time.time() - t0, 3),
                   "contaminated": lk.contaminated, "contamination_events": lk.events}
    with open(os.path.join(out_dir, "run.json"), "w") as f:
        json.dump(summary, f, indent=2)
    return summary


def strip_separator(cmd):
    """Drop only the leading `--` that separates bench.py options from the command."""
    return cmd[1:] if cmd and cmd[0] == "--" else list(cmd)


def cmd_run(args):
    cmd = strip_separator(args.cmd)
    try:
        s = run_timed(cmd, args.out, args.repo, output_base=args.output_base)
    except lockmod.LockBusy as e:
        print("REFUSED: %s" % e, file=sys.stderr)
        return 2
    print(json.dumps(s, indent=2))
    return 3 if s["contaminated"] else s["exit"]


def main(argv=None):
    ap = argparse.ArgumentParser(prog="bench.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("flags")
    f.add_argument("--bazel", default="bazel")
    f.add_argument("--cwd", default=DEFAULT_WS)
    f.add_argument("--extra", nargs="*")
    e = sub.add_parser("env")
    e.add_argument("repo", nargs="?", default=os.getcwd())
    r = sub.add_parser("run")
    r.add_argument("--out", required=True)
    r.add_argument("--repo", default=os.getcwd())
    r.add_argument("--output-base", default=None, help="Bazel output base of the measured run")
    r.add_argument("cmd", nargs=argparse.REMAINDER)
    a = ap.parse_args(argv)
    if a.cmd == "flags":
        return cmd_flags(a)
    if a.cmd == "env":
        print(json.dumps(envmod.capture(a.repo), indent=2))
        return 0
    return cmd_run(a)


if __name__ == "__main__":
    sys.exit(main())
