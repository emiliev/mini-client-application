#!/usr/bin/env python3
"""Union of the per-target coverage.dat files of one package, lib/ files only.

  merge_lcov.py <bazel-out dir> <package-path e.g. utility/mc_paging> [min-percent]
Generated files are excluded (see below).
Exits 1 if the package total is under min-percent (default 90) or no lib file
was measured.
"""
import glob
import os
import re
import sys

logs, pkg = sys.argv[1], sys.argv[2]
minimum = float(sys.argv[3]) if len(sys.argv) > 3 else 90.0
hits = {}  # file -> {line: count}
for dat in glob.glob(os.path.join(logs, "*", "testlogs", pkg, "*", "coverage.dat")):
    cur = None
    for line in open(dat):
        line = line.strip()
        if line.startswith("SF:"):
            cur = line[3:]
            name = os.path.basename(pkg)
            if cur.startswith("package:%s/" % name):
                cur = "lib/" + cur[len("package:%s/" % name):]
                hits.setdefault(cur, {})
            elif cur.startswith("lib/") or (pkg + "/lib/") in cur:
                cur = "lib/" + cur.split("lib/", 1)[1]
                hits.setdefault(cur, {})
            else:
                cur = None
        elif cur and line.startswith("DA:"):
            n, c = line[3:].split(",")[:2]
            d = hits[cur]
            d[int(n)] = d.get(int(n), 0) + int(c)
total = covered = 0
for f in sorted(hits):
    d = hits[f]
    # Generated code is excluded (ADR-0010): freezed, json/retrofit, the
    # injectable config (T-0032) and the gen-l10n outputs (T-0032).
    if f.endswith((".freezed.dart", ".g.dart", ".config.dart")) or re.search(
        r"lib/src/l10n/[^/]*_l10n[^/]*\.dart$", f
    ):
        continue
    cov = sum(1 for c in d.values() if c > 0)
    missed = sorted(n for n, c in d.items() if c == 0)
    total += len(d)
    covered += cov
    print(f"package:{os.path.basename(pkg)}/{f[4:]}: {cov}/{len(d)} "
          f"{100.0 * cov / max(len(d), 1):.1f}% missed={missed}")
pct = 100.0 * covered / total if total else 0.0
print(f"TOTAL {covered}/{total} {pct:.1f}%")
sys.exit(0 if total and pct >= minimum else 1)
