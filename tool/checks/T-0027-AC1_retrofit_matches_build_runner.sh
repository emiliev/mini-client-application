#!/bin/bash
# T-0027-AC1: the fork's retrofit shim (rules patch 0001) produces, for an
# @RestApi file over a freezed + json model and the ApiResponse<T> envelope of
# another package, a `.g.dart` byte-identical to build_runner's from the
# overlay. Also compares the model and envelope outputs, and checks that the
# retrofit action reads the envelope through analyzer summaries.
#
# PASS only if both spike_reference.sh runs exit 0 (which includes a successful
# Bazel build, P-024) and exactly the 5 expected files are reported EQUAL. A
# missing, differing or uncompared file is a FAIL.
#   tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
EXPECTED=(
  spike/api_envelope/lib/src/api_page.g.dart
  spike/api_envelope/lib/src/api_response.g.dart
  spike/retrofit_api/lib/src/character_dto.freezed.dart
  spike/retrofit_api/lib/src/character_dto.g.dart
  spike/retrofit_api/lib/src/characters_api.g.dart
)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rcs=()
for pkg in spike/api_envelope spike/retrofit_api; do
  "$REPO/tool/build_runner_overlay/spike_reference.sh" "$pkg" > "$TMP/run.log" 2>&1
  rcs+=("$pkg exit $?")
  cat "$TMP/run.log" >> "$TMP/all.log"
done
equal=$(grep -E '^EQUAL ' "$TMP/all.log" | awk '{print $2}' | sort)
expected=$(printf '%s\n' "${EXPECTED[@]}" | sort)

BIN="$("$BAZELW" info bazel-bin 2>/dev/null)"
api="$BIN/spike/retrofit_api/lib/src/characters_api.g.dart"
sha=$(shasum -a 256 "$api" 2>/dev/null | cut -c1-64)
generated=$(grep -c '_CharactersApi' "$api" 2>/dev/null)
aq="$("$BAZELW" aquery 'mnemonic(DartCodegen, //spike/retrofit_api:_characters_api_retrofit_part)' --output=text 2>/dev/null)"
summaries=$(grep -o -- '--summary [^ ]*' <<< "$aq" | wc -l | tr -d ' ')
envelope_sum=$(grep -c 'spike/api_envelope/api_envelope.dart_analyzer_summary.sum' <<< "$aq")
sky=$(grep -c 'sky_engine' <<< "$aq")
shim=$(grep -c 'dart/ext/retrofit/shim' <<< "$aq")

# Everything spike_reference.sh printed except build_runner's progress noise:
# Bazel ERROR lines, failure banners and diffs are all kept.
report "# T-0027-AC1: retrofit shim vs build_runner" "" '```' \
  "$(grep -a -v -E '^\s*[0-9]+s (source_gen|freezed|json_serializable|retrofit_generator|go_router_builder|build_runner)' "$TMP/all.log")" '```' "" \
  "| Check | Result |" "|---|---|" \
  "| spike_reference.sh | ${rcs[*]} |" \
  "| expected files EQUAL | $(grep -c . <<< "$equal") of ${#EXPECTED[@]} (must be exactly the list in this script) |" \
  "| \`characters_api.g.dart\` sha256 | \`${sha:-missing}\` |" \
  "| lines naming \`_CharactersApi\` in it | ${generated:-0} |" \
  "| retrofit action runs \`@rules_dart//dart/ext/retrofit:shim\` | $([[ ${shim:-0} -gt 0 ]] && echo yes || echo no) |" \
  "| retrofit action: \`--summary\` args / envelope summary among them / \`sky_engine\` mentions | $summaries / ${envelope_sum:-0} / ${sky:-0} |"
ok=1
[[ "${rcs[*]}" == "spike/api_envelope exit 0 spike/retrofit_api exit 0" ]] || ok=0
[[ "$equal" == "$expected" ]] || ok=0
grep -q -E '^(DIFFER|MISSING|BAZEL BUILD FAILED|ERROR)' "$TMP/all.log" && ok=0
[[ ${generated:-0} -gt 0 && ${shim:-0} -gt 0 && $summaries -gt 0 && ${envelope_sum:-0} -gt 0 && ${sky:-0} -eq 0 ]] || ok=0
finish T-0027-AC1 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
