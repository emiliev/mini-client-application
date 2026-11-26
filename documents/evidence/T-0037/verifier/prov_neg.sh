#!/bin/bash
# Provenance negatives: each breaks one thing, runs the evergreen check,
# expects FAIL, restores.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a23fd7f7ae6d56c1d
S=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0037-verifier
cd "$W" || exit 2
V=third_party/flow_builder
P=$V/0001-navigation-channel-and-popscope.patch
L=$V/lib/flow_builder.dart
cp -f "$P" "$S/patch.bak"; cp -f "$L" "$S/lib.bak"
cleanup() { cp -f "$S/patch.bak" "$P"; cp -f "$S/lib.bak" "$L"; rm -f "$V/0002-extra.patch" "$V/0001-forward-pushRouteInformation.patch"; }
trap cleanup EXIT
run() {
  local name=$1
  tool/checks/T-0035-AC4_provenance.sh > "$S/prov_neg.cur" 2>&1
  local rc=$?
  echo "== $name: exit $rc ($( [ $rc -ne 0 ] && echo FAIL as expected || echo PASSED: NOT CAUGHT ))"
  grep -E '^\| lib/|^\*\*' "$S/prov_neg.cur"
  cleanup
}
# 1. a second patch file next to the real one (an exact copy, so lib/ still matches)
cp "$P" "$V/0002-extra.patch"; run "extra *.patch (copy of the real one)"
# 2. the old patch name back (renamed): no file with the expected name
mv "$P" "$V/0001-forward-pushRouteInformation.patch"; run "patch renamed back to the old name"
# 3. lib/ edited without updating the patch (change 5 removed from lib only)
/usr/bin/python3 -I - "$L" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
old = "        ..add(_state);\n      _recomputeCanPopAfterFrame();\n    } else if"
assert t.count(old) == 1
open(p, "w").write(t.replace(old, "        ..add(_state);\n    } else if"))
PY
run "lib/ loses change 5, patch unchanged"
# 4. the patch edited (one hunk line dropped), lib unchanged
/usr/bin/python3 -I - "$P" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
old = "+      _recomputeCanPopAfterFrame();\n     } else if"
assert t.count(old) == 1
open(p, "w").write(t.replace(old, "     } else if"))
PY
run "patch loses one change-5 line, lib/ unchanged"
# 5. no patch at all
rm -f "$P"; run "no patch file"
