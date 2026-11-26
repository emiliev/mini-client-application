#!/bin/bash
# T-0038 Verifier mutation run at 38354b9 (re-verification). Each mutation edits one file with perl, checks
# the edit applied, runs the three mc_fixtures_comics test targets uncached,
# records which tests fail, and restores the file with git checkout.
#   vmut.sh [ID...]   (default: all)
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76
cd "$W" || exit 2
OB=/tmp/mc-ob-T-0038-verifier
TL="$OB/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/utility/mc_fixtures_comics"
LOG="$W/documents/evidence/T-0038/verifier/mutations_38354b9.log"
P=utility/mc_fixtures_comics
U=$P/lib/src/data/universe.dart
L=$P/lib/src/data/links.dart
H=$P/lib/src/handlers/comics_handlers.dart
D=$P/lib/src/domain.dart
SNAP=$P/test/contract/snapshots/detail.json
V=$P/lib/src/data/vocabulary.dart

# id | file | perl substitution | what it breaks
MUTS=(
"R1|$U|s/final bySeries = a\.seriesTitle\.compareTo\(b\.seriesTitle\);\n  if \(bySeries != 0\) \{\n    return bySeries;\n  \}\n  final byIssue = a\.issueNumber\.compareTo\(b\.issueNumber\);\n  return byIssue != 0 \? byIssue : a\.id\.compareTo\(b\.id\);/final byText = a.title.compareTo(b.title);\n  return byText != 0 ? byText : a.id.compareTo(b.id);/|title order back to a text sort (both orders)"
"R1b|$H|s/'-title': \(a, b\) => _tie\(compareByTitle\(b, a\), a, b\),/'-title': (a, b) => _tie(b.title.compareTo(a.title), a, b),/|-title alone back to a text sort"
"R2|$H|s/: universe\.comicsOfCharacter\(query\.characterId!\);/: const <ComicRecord>[];/|characterId filter returns []"
"R3|$H|s/'Injected HTTP 500 for \\\$\{request\.routeKey\}'/'Injected HTTP 500'/|server_error set message differs from the scenario"
"R3b|$H|s/      'injected_failure',\n      'Injected HTTP 500/      'server_error',\n      'Injected HTTP 500/|server_error set code differs from the scenario"
"R4|$H|s/primary != 0 \? primary : a\.id\.compareTo\(b\.id\)/primary/|id tie-break removed (earlier survivor M13)"
"R5|$U|s/creatorLastNames\[c % creatorLastNames\.length\]/creatorLastNames[(c ~\/ creatorFirstNames.length) % creatorLastNames.length]/|creator surnames partly unreachable (old formula)"
"R6|$V|s/  'Crossing',/  'Gambit',/|banned word Gambit back"
"R7|$V|s/  'Slate',/  'Iron',/|banned word Iron back"
"M1|$U|s/SplitMix64\(seed\)\.fork\('comics'\)/SplitMix64(seed ^ DateTime.now().microsecondsSinceEpoch).fork('comics')/|AC1: seed mixed with the wall clock"
"M4|$L|s/const int characterIdCount = 1500;/const int characterIdCount = 1499;/|AC3 drift: character count constant wrong"
"M8|$SNAP|s/\"pageCount\": (\d+)/'\"pageCount\": '.(\$1+8)/e|AC3: one snapshot value edited"
"M9|$U|s/links\.add\(characterIdBase \+ rng\.nextInt\(characterIdCount\)\)/links.add(characterIdBase + rng.nextInt(characterIdCount + 1))/|AC3: cross-link can point one past the last character"
"M11|$H|s/total: matches\.length,/total: page.length,/|AC2: total counts the page, not the query"
)

want=("$@")
: > "${LOG}.tmp"
killed=0; total=0
for m in "${MUTS[@]}"; do
  IFS='|' read -r id file expr what <<< "$m"
  if [[ ${#want[@]} -gt 0 && ! " ${want[*]} " == *" $id "* ]]; then continue; fi
  total=$((total+1))
  perl -0pi -e "$expr" "$file"
  if git diff --quiet -- "$file"; then
    echo "$id NOT APPLIED ($what)" | tee -a "${LOG}.tmp"
    continue
  fi
  diffline="$(git diff -U0 -- "$file" | grep -E '^[+-][^+-]' | head -4 | tr '\n' ' ')"
  "$W/tool/bazelw" --output_base="$OB" test --nocache_test_results \
    //utility/mc_fixtures_comics:comics_test //utility/mc_fixtures_comics:provider_contract_test \
    //utility/mc_fixtures_comics:fixture_sets_test > "/tmp/mc-T-0038-verifier-mut2-$id.log" 2>&1
  rc=$?
  git checkout -- "$file"
  fails=""
  for t in comics_test provider_contract_test fixture_sets_test; do
    f="$(grep -a -E '^ *FAIL ' "$TL/$t/test.log" 2>/dev/null | sed 's/^ *FAIL *//' | head -12 | tr '\n' ';')"
    [[ -n "$f" ]] && fails="$fails [$t] $f"
  done
  if grep -aq 'FAILED TO BUILD\|ERROR:' "/tmp/mc-T-0038-verifier-mut2-$id.log" && [[ -z "$fails" ]]; then
    fails="(build error) $(grep -a 'Error:' "/tmp/mc-T-0038-verifier-mut2-$id.log" | head -2 | tr '\n' ' ')"
  fi
  if [[ $rc -ne 0 ]]; then verdict=KILLED; killed=$((killed+1)); else verdict=SURVIVED; fi
  {
    echo "$id $verdict ($what)"
    echo "   edit: $diffline"
    echo "   failing: ${fails:-none}"
  } | tee -a "${LOG}.tmp"
done
echo "TOTAL: $killed/$total killed" | tee -a "${LOG}.tmp"
cat "${LOG}.tmp" >> "$LOG"; rm -f "${LOG}.tmp"
git status --short
