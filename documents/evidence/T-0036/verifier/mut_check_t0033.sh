#!/bin/bash
# T-0036 Verifier: (a) the push->go mutation as committed, with its test log
# kept, to see that an assertion (not the compiler) kills it; (b) the committed
# script's mutate() function, extracted verbatim, fed a bare `go` rename that
# cannot compile, to see it is reported as COMPILE ERROR and counts as failure.
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a9c18a5ca6a657e99
cd "$W" || exit 2
F=app/wiring/universe_wiring/lib/src/navigators/characters_list_navigator_impl.dart
trap 'git -C "$W" checkout -- "$F"' EXIT
/usr/bin/python3 -I - "$F" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "_routerRef.router.push(CharacterDetailsRoute(id: id.value).location)"
assert old in s
s = s.replace(old, "Future<void>.sync(\n        () => _routerRef.router.go(CharacterDetailsRoute(id: id.value).location),\n      )", 1)
open(p, "w").write(s)
PY
tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier test --nocache_test_results --test_output=errors \
  //app/wiring/universe_wiring:routes_test > "$S/mut_push_go.log" 2>&1
echo "(a) rc=$?"
tr '\r' '\n' < "$S/mut_push_go.log" | grep -a -E "Build did NOT|FAIL |Expected:|Actual:|Which:|FAILED|PASSED|rror -" | grep -av '^\[' | head -20
git -C "$W" checkout -- "$F"

# (b) the committed mutate(), extracted verbatim from the committed script
sed -n '/^restore() /p; /^mutate() {/,/^}/p' documents/evidence/T-0033/engineer/mutations.sh > "$S/mutate_fn.sh"
OB=/tmp/mc-ob-T-0036-verifier LOG="$S/mut_bare_go.log" rc=0 current="" bash -c '
  OB=/tmp/mc-ob-T-0036-verifier; LOG="$1"; rc=0; current=""
  source "$2"
  mutate "bare go (cannot compile)" "$3" "_routerRef.router.push(" "_routerRef.router.go(" //app/wiring/universe_wiring:routes_test
  echo "(b) script rc would be $rc"
' _ "$S/mut_bare_go.log" "$S/mutate_fn.sh" "$F"
tr '\r' '\n' < "$S/mut_bare_go.log" | grep -a -E "rror -|Build did NOT" | head -5
