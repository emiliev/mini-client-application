"""Own lcov merge: union of DA lines hit across a package's test targets."""
import glob, sys
base = sys.argv[1]
for pkg in ('mc_feature_flags', 'mc_fixtures_platform'):
    hit = {}
    for f in glob.glob(f'{base}/utility/{pkg}/*/coverage.dat'):
        cur = None
        for line in open(f):
            line = line.strip()
            if line.startswith('SF:'):
                cur = line[3:]
            elif line.startswith('DA:') and cur and f'{pkg}/lib/' in cur and '.g.dart' not in cur:
                n, c = line[3:].split(',')[:2]
                k = (cur, n)
                hit[k] = hit.get(k, 0) + int(c)
    tot = len(hit); cov = sum(1 for v in hit.values() if v > 0)
    print(pkg, f'{cov}/{tot}', f'{100*cov/tot:.1f}%' if tot else 'n/a', 'files:', len({k[0] for k in hit}))
