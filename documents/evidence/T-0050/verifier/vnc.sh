#!/bin/bash
# T-0050 Verifier negative control on the editor: the "first write" race
# scenario points its switch step at a route nobody sends and loses its
# `the session belongs to` line, with the tap kept. The scenario must go red.
#   vnc.sh <probe worktree>
set -uo pipefail
cd "$1" || exit 2
F=feature/library/library_reading_list_editor/test/feature/reading_list_editor_races.feature
git diff --quiet -- "$F" || { echo "REFUSING: $F dirty"; exit 2; }
trap 'git checkout -- "$F"' EXIT
/usr/bin/python3 -I - "$F" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
a = s.index("right before the first write of an edit sends nothing")
b = s.index("the app announced {0} change to {'readingLists'}", a)
seg = s[a:b].replace("sends {'PUT /v1/me/lists/l-1'}", "sends {'PUT /v1/me/lists/l-9'}")
seg = seg.replace("    And the session belongs to {'collector@mini-client.test'}\n", "")
assert seg != s[a:b]
open(p, "w").write(s[:a] + seg + s[b:])
EOF
git diff --stat -- "$F"
tool/bazelw --output_base=/tmp/mc-ob-T-0050-verifier-probe test --nocache_test_results --test_output=all \
  //feature/library/library_reading_list_editor:bdd_test 2>&1 | tr '\r' '\n' \
  | grep -a -E "^  FAIL  |never signed in|Executed" | head -8
