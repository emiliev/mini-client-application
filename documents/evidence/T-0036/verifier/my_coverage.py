"""T-0036 Verifier's own LCOV reader (independent of tool/checks/merge_lcov.py).

  my_coverage.py <bazel-out> <repo> <pkg>...
For each package: every coverage.dat under <bazel-out>/*/testlogs/<pkg>/, the
lines of the package's own hand-written lib/ files (generated suffixes
excluded), a line counted covered if any test hit it. Also lists the hit
counts of McFlowBackButton.build's lines.
"""
import os
import sys

out, repo, pkgs = sys.argv[1], sys.argv[2], sys.argv[3:]
GEN = (".g.dart", ".freezed.dart", ".config.dart", ".shard.dart")


def generated(rel):
    base = os.path.basename(rel)
    return base.endswith(GEN) or ("/l10n/" in rel and "_l10n" in base)


for pkg in pkgs:
    name = os.path.basename(pkg)
    lines = {}
    dats = []
    for root, _, files in os.walk(out):
        if "coverage.dat" in files and ("/testlogs/" + pkg + "/") in root + "/":
            dats.append(os.path.join(root, "coverage.dat"))
    for dat in dats:
        sf = None
        for raw in open(dat, errors="replace"):
            raw = raw.rstrip("\n")
            if raw.startswith("SF:"):
                path = raw[3:]
                rel = None
                if path.startswith("package:" + name + "/"):
                    rel = "lib/" + path[len("package:" + name + "/"):]
                elif (pkg + "/lib/") in path:
                    rel = "lib/" + path.split(pkg + "/lib/", 1)[1]
                sf = rel if rel and not generated(rel) else None
            elif raw.startswith("DA:") and sf:
                ln, cnt = raw[3:].split(",")[:2]
                lines.setdefault(sf, {}).setdefault(int(ln), 0)
                lines[sf][int(ln)] += int(cnt)
    tot = sum(len(v) for v in lines.values())
    cov = sum(1 for v in lines.values() for c in v.values() if c > 0)
    on_disk = set()
    for root, _, files in os.walk(os.path.join(repo, pkg, "lib")):
        for f in files:
            if f.endswith(".dart"):
                rel = os.path.relpath(os.path.join(root, f), os.path.join(repo, pkg))
                if not generated(rel):
                    on_disk.add(rel)
    print("== %s: %d coverage.dat, %d/%d lines = %.1f %%" % (pkg, len(dats), cov, tot, 100.0 * cov / max(tot, 1)))
    missing = sorted(on_disk - set(lines))
    print("   hand-written lib files with no LCOV record: %s" % (missing or "none"))
    for f in sorted(lines):
        miss = [ln for ln, c in sorted(lines[f].items()) if c == 0]
        if miss:
            print("   uncovered %s: %s" % (f, miss))
    fc = lines.get("lib/src/flow_context.dart")
    if fc:
        src = open(os.path.join(repo, pkg, "lib/src/flow_context.dart")).read().splitlines()
        start = next(i for i, s in enumerate(src, 1) if "class McFlowBackButton" in s)
        print("   McFlowBackButton line hits:", {ln: c for ln, c in sorted(fc.items()) if ln >= start})
