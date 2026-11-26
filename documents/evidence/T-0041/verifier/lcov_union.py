"""T-0041 Verifier's own LCOV union (independent of tool/checks/merge_lcov.py).

usage: lcov_union.py <testlogs dir> <repo root> <package dir>...
For each package: every coverage.dat under testlogs/<pkg>/, union of DA
lines per hand-written lib/ file (generated .g/.freezed/.config and gen-l10n
outputs excluded), plus the hand-written lib files no report mentions.
"""
import os
import re
import sys

testlogs, repo, pkgs = sys.argv[1], sys.argv[2], sys.argv[3:]
GEN = re.compile(r"\.(g|freezed|config)\.dart$|/l10n/[^/]*_l10n[^/]*\.dart$")
for pkg in pkgs:
    hits = {}
    reports = 0
    root = os.path.join(testlogs, pkg)
    for d, _, files in os.walk(root):
        for f in files:
            if f != "coverage.dat":
                continue
            reports += 1
            cur = None
            for line in open(os.path.join(d, f), errors="replace"):
                line = line.strip()
                if line.startswith("SF:"):
                    sf = line[3:]
                    prefix = "package:" + os.path.basename(pkg) + "/"
                    if sf.startswith(prefix):
                        cur = pkg + "/lib/" + sf[len(prefix):]
                    else:
                        i = sf.find(pkg + "/lib/")
                        cur = sf[i:] if i >= 0 else None
                    if cur and GEN.search(cur):
                        cur = None
                elif line.startswith("DA:") and cur:
                    n, c = line[3:].split(",")[:2]
                    hits.setdefault(cur, {})
                    k = int(n)
                    hits[cur][k] = hits[cur].get(k, 0) + int(c)
    total = sum(len(v) for v in hits.values())
    covered = sum(1 for v in hits.values() for c in v.values() if c > 0)
    print(f"== {pkg}: {reports} reports, {covered}/{total} = "
          f"{100.0 * covered / total if total else 0:.1f} %")
    for f, v in sorted(hits.items()):
        miss = sorted(k for k, c in v.items() if c == 0)
        if miss:
            print(f"   missed {f}: {miss}")
    libdir = os.path.join(repo, pkg, "lib")
    absent = []
    for d, _, files in os.walk(libdir):
        for f in files:
            p = os.path.relpath(os.path.join(d, f), repo)
            if p.endswith(".dart") and not GEN.search(p) and p not in hits:
                absent.append(p)
    print(f"   hand-written lib files in no report: {sorted(absent)}")
