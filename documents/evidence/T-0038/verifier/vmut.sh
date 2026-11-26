#!/bin/bash
# T-0038 Verifier mutation run. Each mutation edits one file with perl, checks
# the edit applied, runs the three mc_fixtures_comics test targets uncached,
# records which tests fail, and restores the file with git checkout.
#   vmut.sh [ID...]   (default: all)
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76
cd "$W" || exit 2
OB=/tmp/mc-ob-T-0038-verifier
TL="$OB/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/utility/mc_fixtures_comics"
LOG="$W/documents/evidence/T-0038/verifier/mutations.log"
P=utility/mc_fixtures_comics
U=$P/lib/src/data/universe.dart
L=$P/lib/src/data/links.dart
H=$P/lib/src/handlers/comics_handlers.dart
D=$P/lib/src/domain.dart
SNAP=$P/test/contract/snapshots/detail.json

# id | file | perl substitution | what it breaks
MUTS=(
"M1|$U|s/SplitMix64\(seed\)\.fork\('comics'\)/SplitMix64(seed ^ DateTime.now().microsecondsSinceEpoch).fork('comics')/|AC1: seed mixed with the wall clock"
"M2|$U|s/^import 'package:mc_fixtures_comics\/src\/data\/links.dart';/import 'dart:math';\nimport 'package:mc_fixtures_comics\/src\/data\/links.dart';/m; s/priceCents: 299 \+ 100 \* rng\.nextInt\(4\)/priceCents: 299 + 100 * Random().nextInt(4)/|AC1: price from an unseeded Random"
"M3|$U|s/^import 'package:mc_fixtures_comics\/src\/data\/links.dart';/import 'dart:collection';\nimport 'package:mc_fixtures_comics\/src\/data\/links.dart';/m; s/for \(final c in byTitle\) \{/for (final c in HashSet<ComicRecord>.identity()..addAll(byTitle)) {/|AC1: per-character index built by iterating an unordered identity set"
"M4|$L|s/const int characterIdCount = 1500;/const int characterIdCount = 1499;/|AC3 drift: character count constant wrong"
"M5|$L|s/const int characterIdBase = 100000;/const int characterIdBase = 100001;/|AC3 drift: character id base constant wrong"
"M6|$L|s/const int coverImageCount = 24;/const int coverImageCount = 23;/|AC3 drift: art-set size constant wrong"
"M7|$L|s/const String coverImageSet = 'characters';/const String coverImageSet = 'comics';/|AC3 drift: art-set name wrong"
"M8|$SNAP|s/\"pageCount\": (\d+)/'\"pageCount\": '.(\$1+8)/e|AC3: one snapshot value edited"
"M9|$U|s/links\.add\(characterIdBase \+ rng\.nextInt\(characterIdCount\)\)/links.add(characterIdBase + rng.nextInt(characterIdCount + 1))/|AC3: cross-link can point one past the last character"
"M10|$U|s/\(index % coverImageCount\)/(index % (coverImageCount + 1))/|AC3: cover can point one past the art set"
"M11|$H|s/total: matches\.length,/total: page.length,/|AC2: total counts the page, not the query"
"M12|$H|s/extra: \{'id': raw\},\n\);\n\nMockResponse _seriesNotFound/extra: {'id': 'x'},\n);\n\nMockResponse _seriesNotFound/|AC2: comic 404 does not name the id"
"M13|$H|s/primary != 0 \? primary : a\.id\.compareTo\(b\.id\)/primary/|AC2: id tie-break removed"
"M14|$D|s/\.\.get\('\/v1\/comics', serverError\)/..get('\/v1\/comics', emptyPage)/|AC2: server_error set list answers 200"
"M15|$D|s/        'GET \/v1\/series\/:id': emptySeriesDetail,\n//|AC2: empty scenario leaves series detail live"
"M16|$H|s/if \(rawCharacter != null && characterId == null\)/if (false)/|AC2: non-numeric characterId accepted"
"M17|$H|s/if \(c\.title\.toLowerCase\(\)\.startsWith\(query\.prefix\)\) c,/if (c.title.startsWith(query.prefix)) c,/|AC2: titleStartsWith case-sensitive"
"M18|$H|s/var matches = query\.characterId == null/var matches = true/|AC2: characterId filter ignored"
"M19|$H|s/min: 1,\n    max: maxLimit,/min: 1,/|AC2: no maximum limit"
"M20|$D|s/'comics\.empty': const MockScenario\(\n      'comics\.empty',\n      overrides: \{\n        'GET \/v1\/comics': emptyPage,/'comics.empty': const MockScenario(\n      'comics.empty',\n      overrides: {/|AC2: empty scenario list still full"
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
    //utility/mc_fixtures_comics:fixture_sets_test > "/tmp/mc-T-0038-verifier-mut-$id.log" 2>&1
  rc=$?
  git checkout -- "$file"
  fails=""
  for t in comics_test provider_contract_test fixture_sets_test; do
    f="$(grep -a -E '^ *FAIL ' "$TL/$t/test.log" 2>/dev/null | sed 's/^ *FAIL *//' | head -6 | tr '\n' ';')"
    [[ -n "$f" ]] && fails="$fails [$t] $f"
  done
  if grep -aq 'FAILED TO BUILD\|ERROR:' "/tmp/mc-T-0038-verifier-mut-$id.log" && [[ -z "$fails" ]]; then
    fails="(build error) $(grep -a 'Error:' "/tmp/mc-T-0038-verifier-mut-$id.log" | head -2 | tr '\n' ' ')"
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
