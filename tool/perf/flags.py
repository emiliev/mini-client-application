"""Flag inventory (T-0016 AC1): every flag in tool/perf/profiles/*.bazelrc and plan 04 §6.3."""
import glob
import os
import re
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))

# Plan 04 §6.3 instrument flags that are not in a profile rc. (kind, name)
PLAN_FLAGS = [
    ("build", "profile"), ("build", "noslim_profile"),
    ("build", "experimental_profile_include_target_label"),
    ("build", "experimental_collect_worker_data_in_profiler"),
    ("build", "memory_profile"), ("build", "memory_profile_stable_heap_parameters"),
    ("build", "starlark_cpu_profile"), ("build", "execution_log_compact_file"),
    ("build", "explain"), ("build", "verbose_explanations"),
    ("build", "build_event_json_file"), ("build", "worker_extra_flag"),
    ("build", "experimental_total_worker_memory_limit_mb"),
    ("build", "experimental_shrink_worker_pool"), ("build", "local_resources"),
    ("startup", "host_jvm_args"),
]

_FLAG_RE = re.compile(r"^\s*--(?:\[no\])?([a-z0-9_]+)")


def inventory(profiles_dir=None):
    """Return a sorted list of (kind, flag) required by the profiles plus the plan list."""
    profiles_dir = profiles_dir or os.path.join(HERE, "profiles")
    need = set(PLAN_FLAGS)
    for rc in sorted(glob.glob(os.path.join(profiles_dir, "*.bazelrc"))):
        with open(rc) as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                m = re.match(r"^(startup|build|common)\s+--(no)?([a-z0-9_]+)", line)
                if m:
                    flag = m.group(3)
                    # `--noslim_profile` style: the negation is a distinct flag name only if the
                    # base is not a boolean; we record the base name and also check `no` form.
                    kind = "startup" if m.group(1) == "startup" else "build"
                    name = ("no" + flag) if m.group(2) and flag == "slim_profile" else flag
                    need.add((kind, name))
    return sorted(need)


def parse_help(text):
    """Flag names present in `bazel help <topic> --long` output."""
    names = set()
    for line in text.splitlines():
        m = _FLAG_RE.match(line)
        if m:
            names.add(m.group(1))
            if "[no]" in line.split(m.group(1))[0]:
                names.add("no" + m.group(1))
    return names


def bazel_help(bazel, topic, cwd):
    r = subprocess.run([bazel, "--output_base=" + cwd_output_base(), "help", topic, "--long"],
                       cwd=cwd, capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        raise RuntimeError("`bazel help %s --long` failed (exit %d): %s"
                           % (topic, r.returncode, r.stderr.strip()[-500:]))
    return r.stdout


def cwd_output_base():
    return os.environ.get("MC_PERF_OUTPUT_BASE", "/tmp/mc-perf-flags-%d" % os.getpid())


def check(bazel, cwd, extra=(), profiles_dir=None, help_fn=None):
    """Return {"available": [...], "missing": [...]} of 'kind:flag' strings."""
    help_fn = help_fn or (lambda topic: bazel_help(bazel, topic, cwd))
    avail = {"startup": parse_help(help_fn("startup_options")),
             "build": parse_help(help_fn("build"))}
    need = set(inventory(profiles_dir)) | set(extra)
    res = {"available": [], "missing": []}
    for kind, flag in sorted(need):
        (res["available"] if flag in avail[kind] else res["missing"]).append(kind + ":" + flag)
    return res


def shutdown(bazel, cwd):
    subprocess.run([bazel, "--output_base=" + cwd_output_base(), "shutdown"], cwd=cwd,
                   capture_output=True, timeout=120)
    shutil.rmtree(cwd_output_base(), ignore_errors=True)
