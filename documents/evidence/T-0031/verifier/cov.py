"""Verifier's own LCOV union: per package, a line is hit if any test hit it.
Also lists lib/ files that never appear in any LCOV (they would be 0 %)."""
import glob, os, sys, collections

TL = "/private/tmp/mc-ob-T-0031-verifier/execroot/_main/bazel-out"
REPO = sys.argv[1]
pkgs = sys.argv[2:]
for pkg in pkgs:
    lines = collections.defaultdict(dict)  # file -> line -> hit
    dats = glob.glob(f"{TL}/*/testlogs/utility/{pkg}/*/coverage.dat")
    for dat in dats:
        sf = None
        for raw in open(dat):
            raw = raw.strip()
            if raw.startswith("SF:"):
                sf = raw[3:]
                # dart_test writes workspace paths; flutter_test package: URIs
                pre = f"utility/{pkg}/lib/"
                if sf.startswith(pre):
                    sf = f"package:{pkg}/" + sf[len(pre):]
            elif raw.startswith("DA:") and sf and sf.startswith(f"package:{pkg}/"):
                ln, hit = raw[3:].split(",")[:2]
                cur = lines[sf].get(int(ln), 0)
                lines[sf][int(ln)] = max(cur, int(hit))
            elif raw == "end_of_record":
                sf = None
    tot = hit = 0
    print(f"== {pkg} ({len(dats)} coverage.dat files)")
    for f in sorted(lines):
        n = len(lines[f]); h = sum(1 for v in lines[f].values() if v > 0)
        miss = sorted(l for l, v in lines[f].items() if v == 0)
        tot += n; hit += h
        print(f"  {f}: {h}/{n} missed={miss}")
    srcs = [os.path.relpath(p, f"{REPO}/utility/{pkg}/lib") for p in glob.glob(f"{REPO}/utility/{pkg}/lib/**/*.dart", recursive=True)]
    absent = [s for s in srcs if f"package:{pkg}/{s}" not in lines]
    print(f"  lib files absent from LCOV (barrels have no executable lines): {absent}")
    print(f"  TOTAL {hit}/{tot} = {100.0*hit/tot if tot else 0:.1f}%")
