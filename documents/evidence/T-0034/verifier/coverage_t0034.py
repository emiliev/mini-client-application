#!/usr/bin/env python3
"""T-0034 Verifier's own LCOV union (independent of merge_lcov.py).

Usage: coverage_t0034.py <testlogs-dir> <pkg-dir> [<pkg-dir> ...]

Reads every coverage.dat under <testlogs-dir>, sums hits per (file, line) and,
for each package directory (e.g. utility/mc_feature_flow), reports covered /
instrumented lines of its hand-written lib/ files. A file is matched by its
`package:<name>/...` URI or by a path containing `<pkg-dir>/lib/`. Generated
files (.g, .freezed, .config, gen-l10n output) are excluded. A hand-written
file on disk that no report mentions is listed as NOT IN ANY REPORT; it counts
as uncovered only when it has executable lines, which LCOV cannot tell, so it
is listed for manual review instead of being guessed."""
import os
import re
import sys
from collections import defaultdict

GEN = re.compile(r"\.(g|freezed|config)\.dart$|_l10n(_[A-Za-z_]+)?\.dart$")
testlogs, pkgs = sys.argv[1], sys.argv[2:]

hits = defaultdict(lambda: defaultdict(int))
for root, _, files in os.walk(testlogs):
    if "coverage.dat" not in files:
        continue
    sf = None
    with open(os.path.join(root, "coverage.dat"), errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("SF:"):
                sf = line[3:]
            elif line.startswith("DA:") and sf is not None:
                num, count = line[3:].split(",")[:2]
                hits[sf][int(num)] += int(count)
            elif line == "end_of_record":
                sf = None

for pkg in pkgs:
    name = os.path.basename(pkg.rstrip("/"))
    libdir = os.path.join(pkg, "lib")
    merged = defaultdict(lambda: defaultdict(int))
    for sf, lines in hits.items():
        rel = None
        if sf.startswith(f"package:{name}/"):
            rel = sf[len(f"package:{name}/"):]
        else:
            m = re.search(re.escape(pkg.rstrip("/")) + r"/lib/(.*)$", sf)
            if m:
                rel = m.group(1)
        if rel is None or GEN.search(rel):
            continue
        for n, h in lines.items():
            merged[rel][n] += h
    on_disk = set()
    for root, _, files in os.walk(libdir):
        for f in files:
            if f.endswith(".dart") and not GEN.search(f):
                on_disk.add(os.path.relpath(os.path.join(root, f), libdir))
    total = covered = 0
    print(f"== {pkg}")
    for rel in sorted(on_disk | set(merged)):
        lines = merged.get(rel)
        if lines is None:
            print(f"  {rel}: NOT IN ANY REPORT")
            continue
        t = len(lines)
        c = sum(1 for h in lines.values() if h > 0)
        total += t
        covered += c
        missed = sorted(n for n, h in lines.items() if h == 0)
        tail = f" missed {missed}" if missed else ""
        print(f"  {rel}: {c}/{t}{tail}")
    pct = 100.0 * covered / total if total else 0.0
    print(f"  TOTAL {covered}/{total} = {pct:.1f} %")
