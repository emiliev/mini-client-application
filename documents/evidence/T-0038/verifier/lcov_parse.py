import sys, collections, os
# Own lcov parser: union of hit lines per file across all given coverage.dat files.
hits = collections.defaultdict(dict)
for path in sys.argv[2:]:
    cur = None
    for line in open(path, errors='replace'):
        line = line.strip()
        if line.startswith('SF:'):
            cur = line[3:]
        elif line.startswith('DA:') and cur:
            n, c = line[3:].split(',')[:2]
            d = hits[cur]
            d[int(n)] = d.get(int(n), 0) + int(c)
        elif line == 'end_of_record':
            cur = None
pfx = sys.argv[1]
tf = th = 0
for f in sorted(hits):
    if not f.startswith(pfx):
        continue
    d = hits[f]; t = len(d); h = sum(1 for v in d.values() if v > 0)
    tf += t; th += h
    miss = sorted(n for n, v in d.items() if v == 0)
    print(f"{f}: {h}/{t} missed={miss}")
print(f"TOTAL {th}/{tf} = {100.0*th/tf:.1f}%")
