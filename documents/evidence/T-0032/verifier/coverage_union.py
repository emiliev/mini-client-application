#!/usr/bin/env python3
"""Verifier's own lcov union: every coverage.dat under the given testlogs dirs,
hits summed per (file, line), restricted to hand-written lib/ files of the
package (generated files excluded by name). Usage: cov.py <pkg-uri-prefix> <hand-written-dir> <dat>..."""
import os, re, sys
from collections import defaultdict

prefix, srcdir, dats = sys.argv[1], sys.argv[2], sys.argv[3:]
GEN = re.compile(r"\.(g|freezed|config)\.dart$|_l10n(_[A-Za-z_]+)?\.dart$")
hits = defaultdict(lambda: defaultdict(int))
for dat in dats:
    sf = None
    for line in open(dat, errors="replace"):
        line = line.strip()
        if line.startswith("SF:"):
            sf = line[3:]
        elif line.startswith("DA:") and sf:
            n, h = line[3:].split(",")[:2]
            hits[sf][int(n)] += int(h)
        elif line == "end_of_record":
            sf = None

def norm(sf):
    # SF is either package:characters_list/... or a path ending in lib/...
    if sf.startswith(prefix):
        return sf[len(prefix):]
    m = re.search(r"feature/characters/characters_list/lib/(.*)$", sf)
    return m.group(1) if m else None

# Hand-written files on disk, so a file no test loaded counts as 0 %.
on_disk = set()
for root, _, files in os.walk(srcdir):
    for f in files:
        if f.endswith(".dart") and not GEN.search(f):
            on_disk.add(os.path.relpath(os.path.join(root, f), srcdir))

per = {}
for sf, lines in hits.items():
    rel = norm(sf)
    if rel is None or GEN.search(rel):
        continue
    d = per.setdefault(rel, defaultdict(int))
    for n, h in lines.items():
        d[n] += h
tot = cov = 0
for rel in sorted(on_disk | set(per)):
    lines = per.get(rel)
    if lines is None:
        print(f"{rel}: NOT IN ANY REPORT")
        continue
    t = len(lines); c = sum(1 for h in lines.values() if h > 0)
    tot += t; cov += c
    missed = sorted(n for n, h in lines.items() if h == 0)
    print(f"{rel}: {c}/{t} {100*c/t:.1f}% missed={missed}")
print(f"TOTAL {cov}/{tot} {100*cov/tot:.1f}%")
