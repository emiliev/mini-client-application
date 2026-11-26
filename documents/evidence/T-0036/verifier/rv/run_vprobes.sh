#!/bin/bash
# T-0036 Verifier: splice the T-0022 Verifier's VPROBE1-4 (committed evidence,
# documents/evidence/T-0022/verifier/probes-cd30e2e.dart.txt) into
# feature_flow_test temporarily, run it uncached, restore.
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a9c18a5ca6a657e99
cd "$W" || exit 2
T=utility/mc_feature_flow/test/feature_flow_test.dart
trap 'git -C "$W" checkout -- "$T"' EXIT
/usr/bin/python3 -I - "$T" documents/evidence/T-0022/verifier/probes-cd30e2e.dart.txt <<'PY' || exit 2
import sys
t, frag = sys.argv[1:3]
lines = open(t).read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("void main()"))
end = next(i for i in range(start, len(lines)) if lines[i] == "}")
f = open(frag).read()
cut = f.index("\n}\n\nclass _V")
body, cls = f[:cut], f[cut + 3:]
lines[end:end] = body.split("\n")
open(t, "w").write("\n".join(lines) + "\n" + cls)
PY
fvm dart format "$T" >/dev/null
tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier test --nocache_test_results --test_output=all \
  //utility/mc_feature_flow:feature_flow_test > "$S/vprobes.raw.log" 2>&1
echo "bazel rc=$?"
tr '\r' '\n' < "$S/vprobes.raw.log" | grep -a -E "  (PASS|FAIL) |Expected:|Actual:|PASSED|FAILED|Executed|rror -" | grep -av '^\['
