#!/bin/bash
# T-0047 verifier mutations. Run from the worktree root.
cd /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad64437dccb81d862 || exit 1
H=utility/mc_fixtures_library/lib/src/handlers/library_handlers.dart
D=utility/mc_fixtures_library/lib/src/data/reading_list.dart
BAK=/tmp/mc-T-0047-verifier/orig.bak
run() { # name file sed-expr
  name="$1"; f="$2"; expr="$3"
  cp "$f" "$BAK"
  sed -i '' -E "$expr" "$f"
  if cmp -s "$f" "$BAK"; then echo "$name: NO-OP"; return; fi
  out=$(fvm flutter test utility/mc_fixtures_library/test 2>&1 | tail -400)
  if grep -q "All tests passed" <<< "$out"; then echo "$name: SURVIVED"
  elif grep -q "Compilation failed\|Error: " <<< "$out"; then echo "$name: BUILD-BROKE"
  else echo "$name: killed ($(grep -E "^[0-9:]+ \+[0-9]+ -[0-9]+: " <<< "$out" | tail -1 | cut -c1-200))"; fi
  cp "$BAK" "$f"
}
run M1-seed-pinned "$H" 's/comicsFor\(context\.seed\)/comicsFor(42)/g'
run M2-id-offset "$H" 's/const int emptyFirstNumber = 1001/const int emptyFirstNumber = 1/'
run M3-name-61 "$D" 's/nameMaxLength = 60/nameMaxLength = 61/'
run M4-403 "$H" "s/^  404,\$/  403,/"
run M5-noauth "$H" "s/userForAuthorization\(request\.headers\['authorization'\]\)/userForAuthorization(request.headers['authorization'] ?? 'Bearer mc-access-u-100-1')/"
run M6-ownership "$H" 's/for \(final list in state\.listsByUser\[user\]!\)/for (final list in state.listsByUser.values.expand((e) => e))/'
run M7-dup "$H" 's/if \(!seen\.add\(id\)\)/if (false \&\& !seen.add(id))/'
run M8-max101 "$D" 's/maxComicsPerList = 100/maxComicsPerList = 101/'
run M9-desc281 "$D" 's/descriptionMaxLength = 280/descriptionMaxLength = 281/'
run M10-sort "$H" "s/^(        \.\.comicIds = \[\.\.\.\(body\['comicIds'\] as List\)\.cast<int>\(\))\]\$/\1..sort()]/"
