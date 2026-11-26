# T-0039 Verifier coverage parser (independent of tool/checks/merge_lcov.py).
# Usage: python3 -I cov.py <bazel output_path> <package dir> ...
# Finds every coverage.dat under the package's testlogs, takes the union of
# hit lines per source file under <package>/lib, prints per-file and total.
import os
import sys

out = sys.argv[1]
for pkg in sys.argv[2:]:
    lines = {}  # file -> {line: hit}
    dats = []
    for root, _, files in os.walk(out):
        if '/testlogs/' + pkg + '/' not in root + '/':
            continue
        for f in files:
            if f == 'coverage.dat':
                dats.append(os.path.join(root, f))
    for dat in dats:
        cur = None
        with open(dat, errors='replace') as fh:
            for raw in fh:
                raw = raw.strip()
                if raw.startswith('SF:'):
                    path = raw[3:]
                    i = path.find(pkg + '/lib/')
                    cur = path[i:] if i >= 0 else None
                    if cur:
                        lines.setdefault(cur, {})
                elif raw.startswith('DA:') and cur:
                    n, h = raw[3:].split(',')[:2]
                    n, h = int(n), int(h)
                    lines[cur][n] = lines[cur].get(n, 0) or h
                elif raw == 'end_of_record':
                    cur = None
    tot = hit = 0
    print(f'== {pkg} ({len(dats)} coverage.dat files)')
    for f in sorted(lines):
        t = len(lines[f])
        h = sum(1 for v in lines[f].values() if v > 0)
        miss = sorted(n for n, v in lines[f].items() if v == 0)
        tot += t
        hit += h
        print(f'  {f}: {h}/{t} missing {miss}')
    pct = 100.0 * hit / tot if tot else 0.0
    print(f'  TOTAL {hit}/{tot} {pct:.1f}%')
