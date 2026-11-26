#!/bin/bash
# T-0042-AC1: on a FRESH CLONE, `tool/ide_sync --env dev` makes the analyzer
# report zero errors; before it, the same analyzer run reports the missing
# generated parts. Both runs are shown.
#   1. git clone of this repo at HEAD (committed state only) into a scratch dir;
#   2. `fvm flutter pub get`, then `fvm dart analyze` over the workspace
#      packages: BEFORE (must report errors about missing generated code, or the
#      claim is vacuous);
#   3. `tool/ide_sync --env dev` against a fresh Bazel output base
#      (MC_FRESH_OUTPUT_BASE, default /tmp/mc-ob-T-0042-fresh, wiped first and
#      shut down at the end);
#   4. the same analyzer run: AFTER (zero errors and zero warnings).
# Negative control: deleting one synced file makes the same AFTER measurement
# report errors again, so the "zero" is not an artefact of the counting.
#   tool/checks/T-0042-AC1_analyzer.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
FRESH="${MC_FRESH_OUTPUT_BASE:-/tmp/mc-ob-T-0042-fresh}"
DIRS=(app feature utility spike third_party tool/l10n_check tool/mc_arch_check)
WORK="$(mktemp -d)"
rc=0
cleanup() {
  "$BAZELW" --output_base="$FRESH" shutdown >/dev/null 2>&1
  chmod -R u+w "$FRESH" 2>/dev/null
  rm -rf "$FRESH" "$WORK"
}
trap cleanup EXIT
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "refusing: uncommitted changes (the clone sees only HEAD)" >&2; exit 2; }
sha="$(git rev-parse HEAD)"

analyze() {  # analyze <dir> <out file>: prints "errors warnings"
  (cd "$1" && fvm dart analyze "${DIRS[@]}" >"$2" 2>&1)
  echo "$(grep -acE '^ *error ' "$2") $(grep -acE '^ *warning ' "$2")"
}

"$BAZELW" --output_base="$FRESH" shutdown >/dev/null 2>&1
chmod -R u+w "$FRESH" 2>/dev/null; rm -rf "$FRESH"
git clone -q --no-checkout "$REPO" "$WORK/clone" && git -C "$WORK/clone" checkout -q "$sha" || { echo "clone failed" >&2; exit 2; }
report "# T-0042-AC1: the analyzer on a fresh clone, before and after tool/ide_sync" "" \
  "Fresh clone of \`$sha\`, workspace packages: \`${DIRS[*]}\`." ""
(cd "$WORK/clone" && fvm flutter pub get >/dev/null 2>&1) || { report "pub get failed in the clone"; finish T-0042-AC1 1; }

read -r e0 w0 <<< "$(analyze "$WORK/clone" "$WORK/before.txt")"
kinds="$(grep -aE '^ *error ' "$WORK/before.txt" | sed -E 's/.* - ([a-z_]+)$/\1/' | sort | uniq -c | sort -rn | head -8 | sed 's/^ */  /')"
report "## Before the sync: $e0 errors, $w0 warnings" '```' "$kinds" '```' "" \
  "Examples:" '```' "$(grep -aE 'uri_has_not_been_generated|uri_does_not_exist|undefined_identifier' "$WORK/before.txt" | head -4)" '```' ""
if [[ "$e0" -gt 0 ]] && grep -aqE 'uri_has_not_been_generated|uri_does_not_exist' "$WORK/before.txt"; then report "- before: errors about missing generated parts, as expected"
else report "- **FAIL**: the analyzer did not report missing generated parts before the sync, so the claim is vacuous"; rc=1; fi

t0=$(date +%s)
(cd "$WORK/clone" && MC_OUTPUT_BASE="$FRESH" tool/ide_sync --env dev >"$WORK/sync.log" 2>&1)
sync_rc=$?
t1=$(date +%s)
report "" "## tool/ide_sync --env dev (fresh output base, warm disk cache): exit $sync_rc in $((t1 - t0)) s" '```' "$(tail -4 "$WORK/sync.log")" '```' ""
[[ $sync_rc == 0 ]] || { report "$(tail -20 "$WORK/sync.log")"; finish T-0042-AC1 1; }
n="$(wc -l <"$WORK/clone/.dart_tool/mc_ide_sync.manifest" | tr -d ' ')"

read -r e1 w1 <<< "$(analyze "$WORK/clone" "$WORK/after.txt")"
report "## After the sync: $e1 errors, $w1 warnings ($n synced files)" '```' "$(tail -4 "$WORK/after.txt")" '```' ""
if [[ "$e1" == 0 && "$w1" == 0 ]]; then report "- after: zero errors and zero warnings"
else report "- **FAIL**: the analyzer still reports problems after the sync" '```' "$(grep -aE '^ *(error|warning) ' "$WORK/after.txt" | head -10)" '```'; rc=1; fi
EV="$REPO/documents/evidence/T-0042/engineer"; mkdir -p "$EV"
cp "$WORK/before.txt" "$EV/AC1_analyze-before.txt"; cp "$WORK/after.txt" "$EV/AC1_analyze-after.txt"

# Negative control: deleting one synced file makes the same AFTER measurement
# report errors again, so the "zero" is not an artefact of the counting.
#   tool/checks/T-0042-AC1_analyzer.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
FRESH="${MC_FRESH_OUTPUT_BASE:-/tmp/mc-ob-T-0042-fresh}"
DIRS=(app feature utility spike third_party tool/l10n_check tool/mc_arch_check)
WORK="$(mktemp -d)"
rc=0
cleanup() {
  "$BAZELW" --output_base="$FRESH" shutdown >/dev/null 2>&1
  chmod -R u+w "$FRESH" 2>/dev/null
  rm -rf "$FRESH" "$WORK"
}
trap cleanup EXIT
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "refusing: uncommitted changes (the clone sees only HEAD)" >&2; exit 2; }
sha="$(git rev-parse HEAD)"

analyze() {  # analyze <dir> <out file>: prints "errors warnings"
  (cd "$1" && fvm dart analyze "${DIRS[@]}" >"$2" 2>&1)
  echo "$(grep -acE '^ *error ' "$2") $(grep -acE '^ *warning ' "$2")"
}

"$BAZELW" --output_base="$FRESH" shutdown >/dev/null 2>&1
chmod -R u+w "$FRESH" 2>/dev/null; rm -rf "$FRESH"
git clone -q --no-checkout "$REPO" "$WORK/clone" && git -C "$WORK/clone" checkout -q "$sha" || { echo "clone failed" >&2; exit 2; }
report "# T-0042-AC1: the analyzer on a fresh clone, before and after tool/ide_sync" "" \
  "Fresh clone of \`$sha\`, workspace packages: \`${DIRS[*]}\`." ""
(cd "$WORK/clone" && fvm flutter pub get >/dev/null 2>&1) || { report "pub get failed in the clone"; finish T-0042-AC1 1; }

read -r e0 w0 <<< "$(analyze "$WORK/clone" "$WORK/before.txt")"
kinds="$(grep -aE '^ *error ' "$WORK/before.txt" | sed -E 's/.* - ([a-z_]+)$/\1/' | sort | uniq -c | sort -rn | head -8 | sed 's/^ */  /')"
report "## Before the sync: $e0 errors, $w0 warnings" '```' "$kinds" '```' "" \
  "Examples:" '```' "$(grep -aE 'uri_has_not_been_generated|uri_does_not_exist|undefined_identifier' "$WORK/before.txt" | head -4)" '```' ""
if [[ "$e0" -gt 0 ]] && grep -aqE 'uri_has_not_been_generated|uri_does_not_exist' "$WORK/before.txt"; then report "- before: errors about missing generated parts, as expected"
else report "- **FAIL**: the analyzer did not report missing generated parts before the sync, so the claim is vacuous"; rc=1; fi

t0=$(date +%s)
(cd "$WORK/clone" && MC_OUTPUT_BASE="$FRESH" tool/ide_sync --env dev >"$WORK/sync.log" 2>&1)
sync_rc=$?
t1=$(date +%s)
report "" "## tool/ide_sync --env dev (fresh output base, warm disk cache): exit $sync_rc in $((t1 - t0)) s" '```' "$(tail -4 "$WORK/sync.log")" '```' ""
[[ $sync_rc == 0 ]] || { report "$(tail -20 "$WORK/sync.log")"; finish T-0042-AC1 1; }
n="$(wc -l <"$WORK/clone/.dart_tool/mc_ide_sync.manifest" | tr -d ' ')"

read -r e1 w1 <<< "$(analyze "$WORK/clone" "$WORK/after.txt")"
report "## After the sync: $e1 errors, $w1 warnings ($n synced files)" '```' "$(tail -4 "$WORK/after.txt")" '```' ""
if [[ "$e1" == 0 && "$w1" == 0 ]]; then report "- after: zero errors and zero warnings"
else report "- **FAIL**: the analyzer still reports problems after the sync" '```' "$(grep -aE '^ *(error|warning) ' "$WORK/after.txt" | head -10)" '```'; rc=1; fi
cp "$WORK/before.txt" "$WORK/after.txt" "$REPO/documents/evidence/T-0042/engineer/" 2>/dev/null
mv "$REPO/documents/evidence/T-0042/engineer/before.txt" "$REPO/documents/evidence/T-0042/engineer/AC1_analyze-before.txt" 2>/dev/null
mv "$REPO/documents/evidence/T-0042/engineer/after.txt" "$REPO/documents/evidence/T-0042/engineer/AC1_analyze-after.txt" 2>/dev/null

# Negative control: remove one synced file; the same measurement must fail again.
victim=feature/characters/characters_list/lib/src/domain/model/character.freezed.dart
rm -f "$WORK/clone/$victim"
read -r e2 _ <<< "$(analyze "$WORK/clone" "$WORK/neg.txt")"
if [[ "$e2" -gt 0 ]]; then report "- negative control: without \`$(basename "$victim")\` the same analyzer run reports $e2 errors"
else report "- **FAIL** negative control: the analyzer reported no error with a synced file missing"; rc=1; fi

finish T-0042-AC1 $rc
