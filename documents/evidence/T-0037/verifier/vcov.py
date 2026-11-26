"""T-0037 Verifier's own LCOV union: for each package prefix, take every
coverage.dat under the Bazel testlogs, keep SF records under <prefix>/lib/,
union the hit lines per file across targets, and print per-file and total %.

usage: python3 -I vcov.py <testlogs dir> <pkg prefix>...
"""
import os
import sys

testlogs, prefixes = sys.argv[1], sys.argv[2:]
lines = {}  # file -> {line: hit?}
for root, _, files in os.walk(testlogs):
    for name in files:
        if name != "coverage.dat":
            continue
        sf = None
        for raw in open(os.path.join(root, name), errors="replace"):
            raw = raw.strip()
            if raw.startswith("SF:"):
                sf = raw[3:]
                # normalise absolute or execroot paths to repo-relative
                for p in prefixes:
                    pkg = "package:" + os.path.basename(p) + "/"
                    i = sf.find(p + "/lib/")
                    if sf.startswith(pkg):
                        sf = p + "/lib/" + sf[len(pkg):]
                        break
                    if i >= 0:
                        sf = sf[i:]
                        break
                else:
                    sf = None
            elif raw.startswith("DA:") and sf:
                n, hits = raw[3:].split(",")[:2]
                d = lines.setdefault(sf, {})
                d[int(n)] = d.get(int(n), False) or int(hits) > 0
            elif raw == "end_of_record":
                sf = None
for p in prefixes:
    tot = hit = 0
    print("==", p)
    for f in sorted(k for k in lines if k.startswith(p + "/lib/")):
        if f.endswith((".g.dart", ".freezed.dart", ".config.dart")):
            continue
        d = lines[f]
        h = sum(d.values())
        tot += len(d)
        hit += h
        print(f"  {100.0 * h / len(d):6.1f} %  {h:4d}/{len(d):4d}  {f}")
    print(f"TOTAL {p}: {hit}/{tot} = {100.0 * hit / tot if tot else 0:.1f} %")
