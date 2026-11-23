"""Trace profile and BEP parsing (T-0016 AC5).

Phase totals follow `bazel analyze-profile` semantics: each "build phase marker" starts a phase that
lasts until the next marker; the last phase ends at the end of the profile (latest event end).
Times are returned in milliseconds, rounded to 3 decimals.
"""
import gzip
import json
import sys


def load_trace(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as f:
        return json.load(f)


def phase_totals(trace):
    events = trace["traceEvents"] if isinstance(trace, dict) else trace
    markers = sorted((e["ts"], e["name"]) for e in events
                     if e.get("cat") == "build phase marker" and e.get("ph") == "i")
    if not markers:
        return {}
    end = max((e.get("ts", 0) + e.get("dur", 0)) for e in events if e.get("ph") in ("X", "i"))
    totals = {}
    for i, (ts, name) in enumerate(markers):
        nxt = markers[i + 1][0] if i + 1 < len(markers) else end
        totals[name] = round((nxt - ts) / 1000.0, 3)
    return totals


def analyze_profile_available(bazel_help_text):
    return "analyze-profile" in bazel_help_text


def parse_analyze_profile(text):
    """Parse `bazel analyze-profile` phase lines, e.g. 'Load, analyze ... 0.123 s  45.6 %'."""
    import re
    out = {}
    for line in text.splitlines():
        m = re.match(r"^\s*(.+?)\s+([0-9.]+)\s*s\s+[0-9.]+\s*%\s*$", line)
        if m:
            out[m.group(1)] = round(float(m.group(2)) * 1000, 3)
    return out


def within(a, b, tol=0.01):
    """True if two phase-total dicts agree within `tol` relative error per phase."""
    for k, v in b.items():
        if k not in a:
            return False
        if v == 0:
            if a[k] != 0:
                return False
        elif abs(a[k] - v) / v > tol:
            return False
    return True


def _ms(key, v):
    """BEP values: `*InMs` fields are already milliseconds (int64 strings); Duration-typed
    values carry an `s` suffix ('0.053862s') and are converted to milliseconds."""
    sv = str(v)
    if sv.endswith("s") and not key.endswith("InMs"):
        return float(sv[:-1]) * 1000.0
    return float(sv)


def bep_timing(path):
    """Return BuildMetrics timing (ms) from a --build_event_json_file (newline-delimited JSON)."""
    with open(path) as f:
        for line in f:
            ev = json.loads(line)
            bm = ev.get("buildMetrics")
            if bm:
                t = bm.get("timingMetrics", {})
                return {k: _ms(k, v) for k, v in t.items()}
    return {}


if __name__ == "__main__":
    print(json.dumps(phase_totals(load_trace(sys.argv[1])), indent=2))
