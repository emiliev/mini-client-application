#!/bin/bash
# T-0043 engineer mutation checks: each mutation of the discovery package must
# turn at least one test red (a mutation that survives, or that fails to
# build, fails this script). Ranking tiers and tie-breaks are pinned one by one.
#
#   MC_TASK=T-0043 MC_ROLE=engineer documents/evidence/T-0043/engineer/mutations.sh
#
# Run from a clean, committed tree: every mutation is undone with
# `git checkout -- <package>`, which would also discard uncommitted edits.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
: "${MC_TASK:?set MC_TASK, e.g. T-0043}"
: "${MC_ROLE:?set MC_ROLE, e.g. engineer}"
if [[ -n "$(git status --porcelain utility/mc_fixtures_discovery)" ]]; then
  echo "refusing to run: utility/mc_fixtures_discovery has uncommitted changes" >&2
  exit 2
fi
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
P=utility/mc_fixtures_discovery
IDX=$P/lib/src/search/index.dart
NORM=$P/lib/src/search/normalize.dart
H=$P/lib/src/handlers/search_handlers.dart
DOM=$P/lib/src/domain.dart
LOG="$(mktemp -t "mc-$MC_TASK-$MC_ROLE-mut.XXXXXX")"
trap 'git checkout -- "$P"; rm -f "$LOG"' EXIT
killed=0
survived=0
broken=0

run_tests() {
  tool/bazelw --output_base="$OB" test //$P/... > "$LOG" 2>&1
}

# mutate <name> <file> <old> <new>
mutate() {
  local name="$1" file="$2" old="$3" new="$4"
  echo "=== $name"
  if ! python3 -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if old not in s:
    sys.exit("pattern not found: " + old)
open(p, "w").write(s.replace(old, new, 1))
' "$file" "$old" "$new"; then
    echo "    PATTERN NOT FOUND"; broken=$((broken + 1)); git checkout -- "$P"; return
  fi
  run_tests
  local failed
  failed="$(tr '\r' '\n' < "$LOG" | grep -aE '^//.*FAILED' | sed 's/ *FAILED.*//' | tr '\n' ' ')"
  if [[ -n "$failed" ]]; then
    echo "    KILLED by: $failed"
    killed=$((killed + 1))
  elif tr '\r' '\n' < "$LOG" | grep -aq 'Build did NOT complete'; then
    echo "    BUILD ERROR (does not count as killed)"
    tr '\r' '\n' < "$LOG" | grep -aE 'error|info -|warning' | head -3
    broken=$((broken + 1))
  else
    echo "    SURVIVED"; survived=$((survived + 1))
  fi
  git checkout -- "$P"
}

# Baseline: the unmutated tree must pass.
run_tests || { echo "BASELINE FAILS"; tr '\r' '\n' < "$LOG" | tail -20; exit 1; }
echo "baseline PASS"

# --- tiers -------------------------------------------------------------
mutate "T1 tier order reversed" $IDX \
  "a.tier.index.compareTo(b.tier.index)" "b.tier.index.compareTo(a.tier.index)"
mutate "T2 tier ignored in the ranking" $IDX \
  "final byTier = a.tier.index.compareTo(b.tier.index);" "final byTier = 0;"
mutate "T3 exact tier removed (exact counts as prefix)" $IDX \
  "return MatchTier.exact;" "return MatchTier.prefix;"
mutate "T4 prefix tier removed (prefix counts as word-prefix)" $IDX \
  "return MatchTier.prefix;" "return MatchTier.wordPrefix;"
mutate "T5 word-prefix tier removed (counts as substring)" $IDX \
  "tier = MatchTier.wordPrefix;" "tier = MatchTier.substring;"
mutate "T6 substring tier removed (counts as word-prefix)" $IDX \
  "var tier = MatchTier.substring;" "var tier = MatchTier.wordPrefix;"
mutate "T7 word boundary not checked" $IDX \
  "if (_notWordChar.hasMatch(foldedTitle[at - 1])) {" "if (_notWordChar.hasMatch(foldedTitle[at - 1]) || at > 0) {"
mutate "T8 a later boundary occurrence is not looked for" $IDX \
  "at = foldedTitle.indexOf(foldedQuery, at + 1);" "at = -1;"

# --- tie-breaks --------------------------------------------------------
mutate "B1 title tie-break removed" $IDX \
  "final byTitle = a.entry.title.compareTo(b.entry.title);" "final byTitle = 0;"
mutate "B2 title compared folded, not as written" $IDX \
  "a.entry.title.compareTo(b.entry.title)" "a.entry.folded.compareTo(b.entry.folded)"
mutate "B3 type tie-break removed" $IDX \
  "if (byType != 0) {" "if (byType != 0 && a.entry.id < 0) {"
mutate "B4 id tie-break removed" $IDX \
  "return a.entry.id.compareTo(b.entry.id);" "return 0;"
mutate "B5 id tie-break descending" $IDX \
  "return a.entry.id.compareTo(b.entry.id);" "return b.entry.id.compareTo(a.entry.id);"

# --- folding -----------------------------------------------------------
mutate "F1 case not folded" $NORM \
  "text.toLowerCase().runes" "text.runes"
mutate "F2 diacritics not folded" $NORM \
  "out.write(_foldTable[rune] ?? char);" "out.write(_foldTable[rune] == null ? char : char);"
mutate "F3 combining marks kept" $NORM \
  "if (_isCombining(rune)) {" "if (_isCombining(rune) && rune < 0) {"
mutate "F4 whitespace not collapsed" $NORM \
  "if (space && out.isNotEmpty) {
      out.write(' ');
    }" "if (space && out.isNotEmpty) {
      out.write('');
    }"

# --- review round fixes ------------------------------------------------
mutate "R1 minimum length checked on the raw q, not the folded one" $H \
  "foldText(q).runes.length < minQueryLength" "q.runes.length < minQueryLength"
mutate "R2 word boundary read as a UTF-16 unit" $IDX \
  "if (isLow && index >= 2) {" "if (isLow && index >= 2 && index < 0) {"
mutate "R3 comma-below s not folded" $NORM \
  "'s': 'śŝşšșṡṣṥṧṩ'," "'s': 'śŝşšṡṣṥṧṩ',"
mutate "R4 Vietnamese a with circumflex and acute not folded" $NORM \
  "'a': 'àáâãäåāăąǎạảấầ" "'a': 'àáâãäåāăąǎạảầ"
mutate "R5 entry type not validated" $IDX \
  "if (!searchTypes.contains(type)) {" "if (!searchTypes.contains(type) && type.isEmpty) {"

# --- handlers ----------------------------------------------------------
mutate "H1 groups follow the order of types" $H \
  "for (final type in searchTypes)
        if (params.types.contains(type))" "for (final type in params.types)
        if (params.types.contains(type))"
mutate "H2 total counts only the page" $H \
  "'total': all.length," "'total': all.take(limit).length,"
mutate "H3 minimum query length 1" $H \
  "const int minQueryLength = 2;" "const int minQueryLength = 1;"
mutate "H4 q not trimmed" $H \
  "(request.query['q'] ?? '').trim()" "(request.query['q'] ?? '').replaceAll('x', 'x')"
mutate "H5 unknown types accepted" $H \
  "asked.any((t) => !searchTypes.contains(t))" "asked.isEmpty && asked.any((t) => !searchTypes.contains(t))"
mutate "H6 limit upper bound off by one" $H \
  "value > maxLimit ? null" "value > maxLimit + 1 ? null"
mutate "H7 limit lower bound off by one" $H \
  "value < 1 || value > maxLimit" "value < 0 || value > maxLimit"
mutate "H8 suggestions give 6" $H \
  "const int suggestionCount = 5;" "const int suggestionCount = 6;"
mutate "H9 suggestions repeat a title" $H \
  "if (!titles.contains(m.entry.title)) {" "if (titles.length < suggestionCount) {"
mutate "H10 server_error set body differs from the scenario" $H \
  "'injected_failure',
      'Injected HTTP 500" "'server_error',
      'Injected HTTP 500"
mutate "H11 query echoed in lower case" $H \
  "'query': params.query," "'query': params.query.toLowerCase(),"
mutate "H12 default limit 10" $H \
  "const int defaultLimit = 20;" "const int defaultLimit = 10;"

# --- domain and index --------------------------------------------------
mutate "D1 empty set serves the full index" $DOM \
  "_registerRoutes(router, SearchIndex.empty);" \
  "_registerRoutes(router, SearchIndex.fromUniverses(0, environment.clock));"
mutate "D2 comic thumbnail is the wrong image" $IDX \
  "thumbnail: c.cover," "thumbnail: c.variants.isEmpty ? c.cover : c.variants.first.cover,"
mutate "D3 character index skips the last half" $IDX \
  "for (final c in CharacterUniverse(seed, clock).byName)" \
  "for (final c in CharacterUniverse(seed, clock).byName.take(750))"
mutate "D4 comics index missing" $IDX \
  "for (final c in ComicUniverse(seed).byTitle)" "for (final c in ComicUniverse(seed).byTitle.take(0))"
echo
echo "killed=$killed survived=$survived broken=$broken"
git status --short "$P"
[[ $survived -eq 0 && $broken -eq 0 ]]
