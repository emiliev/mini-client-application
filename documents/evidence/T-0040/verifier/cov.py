"""T-0040 Verifier coverage parser (independent of tool/checks/merge_lcov.py).
cov.py <testlogs dir> <repo> <pkg path> [<pkg path>...]
For each package: union of DA lines over every coverage.dat under
<testlogs>/<pkg path>/, keyed by lib file. Accepts both SF forms
(`package:<name>/...` and workspace-relative `<pkg>/lib/...`). Generated files
(*.g.dart, *.freezed.dart, *.config.dart, lib/src/l10n/*) are excluded. Lists
hand-written lib files that never appear in LCOV."""
import glob
import os
import re
import sys

GEN = re.compile(r'(\.g\.dart|\.freezed\.dart|\.config\.dart)$|/l10n/')

testlogs, repo, pkgs = sys.argv[1], sys.argv[2], sys.argv[3:]
for pkg in pkgs:
    name = os.path.basename(pkg)
    lines = {}
    files = glob.glob(os.path.join(testlogs, pkg, '**', 'coverage.dat'), recursive=True)
    for f in files:
        sf = None
        for raw in open(f):
            raw = raw.strip()
            if raw.startswith('SF:'):
                p = raw[3:]
                if p.startswith(f'package:{name}/'):
                    sf = 'lib/' + p[len(f'package:{name}/'):]
                elif p.startswith(pkg + '/lib/'):
                    sf = p[len(pkg) + 1:]
                else:
                    sf = None
            elif raw.startswith('DA:') and sf and not GEN.search(sf):
                ln, hits = raw[3:].split(',')[:2]
                d = lines.setdefault(sf, {})
                d[int(ln)] = d.get(int(ln), 0) + int(hits)
    total = sum(len(v) for v in lines.values())
    hit = sum(1 for v in lines.values() for h in v.values() if h > 0)
    print(f'== {pkg}: {len(files)} coverage.dat, {hit}/{total} = {100.0 * hit / max(total, 1):.1f} %')
    for sf in sorted(lines):
        miss = sorted(l for l, h in lines[sf].items() if h == 0)
        print(f'   {sf}: {sum(1 for h in lines[sf].values() if h)}/{len(lines[sf])}' + (f' missed {miss}' if miss else ''))
    libs = [os.path.relpath(p, os.path.join(repo, pkg)) for p in glob.glob(os.path.join(repo, pkg, 'lib', '**', '*.dart'), recursive=True)]
    absent = sorted(l for l in libs if l not in lines and not GEN.search(l))
    print(f'   lib files absent from LCOV: {absent or "none"}')
