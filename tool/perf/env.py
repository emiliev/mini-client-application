"""Environment capture (T-0016 AC3). Python 3.9 stdlib only; run as `python3 -I env.py`."""
import hashlib
import json
import os
import re
import subprocess
import sys

BENCH_VERSION = 1
DRIFT_LIMIT = 0.05


def sh(argv, cwd=None, timeout=30):
    """Run a command and return stripped stdout, or None if it is missing or fails."""
    try:
        r = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip()


def first_line(s):
    return s.splitlines()[0] if s else None


def machine_id():
    out = sh(["/usr/sbin/ioreg", "-rd1", "-c", "IOPlatformExpertDevice"])
    m = re.search(r'"IOPlatformUUID" = "([^"]+)"', out or "")
    raw = m.group(1) if m else (os.uname().nodename)
    return hashlib.sha256(raw.encode()).hexdigest()[:16]  # hashed: not a stable hardware id


def power_source(pmset_out=None):
    out = pmset_out if pmset_out is not None else sh(["/usr/bin/pmset", "-g", "batt"])
    if not out:
        return "unknown"
    if "AC Power" in out:
        return "ac"
    if "Battery Power" in out:
        return "battery"
    return "unknown"


def thermal_state(therm_out=None):
    """'nominal' unless `pmset -g therm` reports a CPU speed limit below 100."""
    out = therm_out if therm_out is not None else sh(["/usr/bin/pmset", "-g", "therm"])
    if out is None:
        return "unknown"
    m = re.search(r"CPU_Speed_Limit\s*=\s*(\d+)", out)
    if m and int(m.group(1)) < 100:
        return "limited:" + m.group(1)
    return "nominal"


def drift(reference, measured):
    """Relative drift of a calibration value from this machine's reference."""
    return abs(measured - reference) / reference


def machine_drift(reference, measured, limit=DRIFT_LIMIT):
    """AC3: drift above 5 % is flagged `machine_drift`. Both are dicts name -> seconds."""
    flagged = {}
    for k, ref in reference.items():
        if k in measured and ref > 0:
            d = drift(ref, measured[k])
            if d > limit:
                flagged[k] = round(d, 4)
    return {"machine_drift": bool(flagged), "drifted": flagged}


def repo_sha(repo):
    return sh(["git", "rev-parse", "HEAD"], cwd=repo)


def capture(repo, profile="none", bazel="bazel", calibration=None, reference=None):
    """Build the env.json document. Tools that are not installed are recorded as null."""
    env = {
        "bench_version": BENCH_VERSION,
        "repo_sha": repo_sha(repo),
        "bazel": first_line(sh([bazel, "--version"])),
        "flutter": first_line(sh(["fvm", "flutter", "--version"], cwd=repo)),
        "dart": first_line(sh(["fvm", "dart", "--version"], cwd=repo)),
        "xcode": " ".join((sh(["xcodebuild", "-version"]) or "").split()) or None,
        "macos": sh(["sw_vers", "-productVersion"]),
        "machine_id": machine_id(),
        "power_source": power_source(),
        "thermal_state": thermal_state(),
        "profile": profile,
        "python": sys.version.split()[0],
    }
    env["machine_drift"] = False
    if calibration is not None and reference is not None:
        env.update(machine_drift(reference, calibration))
        env["calibration"] = calibration
    return env


def main(argv):
    repo = argv[1] if len(argv) > 1 else os.getcwd()
    print(json.dumps(capture(repo), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
