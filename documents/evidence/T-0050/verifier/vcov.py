"""T-0050 Verifier's own LCOV reader (independent of tool/checks/merge_lcov.py).

vcov.py <bazel-out> <repo> <pkg>...
For each package: unions DA lines over that package's own test targets' coverage.dat,
keyed by the absolute-ish source path, and also lists every hand-written lib/*.dart
file on disk that no coverage.dat mentions (a file never loaded would be invisible
to a union-only count).
"""
import os
import re
import sys
from pathlib import Path

out, repo, pkgs = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]
GEN = re.compile(r"(\.freezed|\.g|\.config)\.dart$|/l10n/[^/]*_l10n[^/]*\.dart$")

for pkg in pkgs:
    name = pkg.rsplit("/", 1)[1]
    lines: dict[str, dict[int, int]] = {}
    dats = list(out.glob(f"*/testlogs/{pkg}/*/coverage.dat"))
    for dat in dats:
        sf = None
        for raw in dat.read_text().splitlines():
            if raw.startswith("SF:"):
                p = raw[3:]
                m = re.match(rf"package:{name}/(.*)", p)
                if m:
                    sf = "lib/" + m.group(1)
                elif f"{pkg}/lib/" in p:
                    sf = "lib/" + p.split(f"{pkg}/lib/", 1)[1]
                else:
                    sf = None
            elif raw.startswith("DA:") and sf:
                ln, hit = raw[3:].split(",")[:2]
                lines.setdefault(sf, {})
                lines[sf][int(ln)] = lines[sf].get(int(ln), 0) + int(hit)
            elif raw == "end_of_record":
                sf = None
    on_disk = {
        str(f.relative_to(repo / pkg))
        for f in (repo / pkg / "lib").rglob("*.dart")
        if not GEN.search(str(f))
    }
    measured = {f for f in lines if not GEN.search(f)}
    tot = cov = 0
    for f in sorted(measured):
        d = lines[f]
        tot += len(d)
        cov += sum(1 for v in d.values() if v)
        miss = [n for n, v in sorted(d.items()) if not v]
        if miss:
            print(f"  {pkg}/{f}: missed lines {miss}")
    unseen = sorted(on_disk - measured)
    print(f"{pkg}: {cov}/{tot} = {100 * cov / max(tot, 1):.2f}% over {len(dats)} "
          f"coverage.dat; lib files never in LCOV: {unseen or 'none'}")
