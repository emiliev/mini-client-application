#!/bin/bash
cd /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949 || exit 2
P=utility/mc_fixtures_discovery
IDX=$P/lib/src/search/index.dart; NORM=$P/lib/src/search/normalize.dart; H=$P/lib/src/handlers/search_handlers.dart
SNAP=$P/test/contract/snapshots/search_spi.json
mut() { # name file old new
  python3 -I -c '
import sys
p,o,n=sys.argv[1:4]; s=open(p).read()
assert o in s, "not found"
open(p,"w").write(s.replace(o,n,1))' "$2" "$3" "$4" || { echo "$1: PATTERN NOT FOUND"; return; }
  out=$(tool/bazelw --output_base=/tmp/mc-ob-T-0043-verifier test //$P/... 2>&1 | tr '\r' '\n')
  f=$(grep -aE '^//.*FAILED' <<<"$out" | sed 's/ *FAILED.*//' | tr '\n' ' ')
  if [[ -n "$f" ]]; then echo "$1: KILLED by $f"; elif grep -aq 'did NOT complete' <<<"$out"; then echo "$1: BUILD ERROR"; else echo "$1: SURVIVED"; fi
  git checkout -- $P
}
mut M1-prefix-as-wordprefix $IDX "return MatchTier.prefix;" "return MatchTier.wordPrefix;"
mut M2-wordprefix-as-substring $IDX "tier = MatchTier.wordPrefix;" "tier = MatchTier.substring;"
mut M3-title-tiebreak-reversed $IDX "a.entry.title.compareTo(b.entry.title)" "b.entry.title.compareTo(a.entry.title)"
mut M4-snapshot-edited $SNAP '"total": 152' '"total": 153'
mut R1-folded-length $H "foldText(q).runes.length < minQueryLength" "q.runes.length < minQueryLength"
mut R2-utf16-boundary $IDX "if (isLow && index >= 2) {" "if (false) {"
mut R3-wider-folding $NORM "ẹẻẽếềểễệḕḗḙḛḝ" "ẹẻẽ"
mut R4-comma-below $NORM "śŝşšșṡ" "śŝşšṡ"
mut R5-entry-type-check $IDX "if (!searchTypes.contains(type)) {" "if (false) {"
mut M6-group-order $H "for (final type in searchTypes)" "for (final type in params.types)"
echo FINISHED
