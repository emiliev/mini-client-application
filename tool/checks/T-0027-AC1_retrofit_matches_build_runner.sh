#!/bin/bash
# T-0027-AC1: the fork's retrofit shim (rules patch 0001) produces, for an
# @RestApi file over a freezed + json model and the ApiResponse<T> envelope of
# another package, a `.g.dart` byte-identical to build_runner's from the
# overlay. Also compares the model and envelope outputs, and checks that the
# retrofit action reads the envelope through analyzer summaries.
#   tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
lines=()
for pkg in spike/api_envelope spike/retrofit_api; do
  log="$(mktemp)"
  "$REPO/tool/build_runner_overlay/spike_reference.sh" "$pkg" > "$log" 2>&1 || rc=1
  lines+=("$(grep -E '^(==|   |EQUAL|DIFFER|MISSING|DRIFT|UNRESOLVED|[-+@ ])' "$log")")
  rm -f "$log"
done
BIN="$("$BAZELW" info bazel-bin 2>/dev/null)"
api="$BIN/spike/retrofit_api/lib/src/characters_api.g.dart"
sha=$(shasum -a 256 "$api" 2>/dev/null | cut -c1-64)
generated=$(grep -c '_CharactersApi' "$api" 2>/dev/null || echo 0)
aq="$("$BAZELW" aquery 'mnemonic(DartCodegen, //spike/retrofit_api:_characters_api_retrofit_part)' --output=text 2>/dev/null)"
summaries=$(grep -o -- '--summary [^ ]*' <<< "$aq" | wc -l | tr -d ' ')
envelope_sum=$(grep -c 'spike/api_envelope/api_envelope.dart_analyzer_summary.sum' <<< "$aq" || true)
sky=$(grep -c 'sky_engine' <<< "$aq" || true)
shim=$(grep -c 'dart/ext/retrofit/shim' <<< "$aq" || true)

report "# T-0027-AC1: retrofit shim vs build_runner" "" '```' "${lines[@]}" '```' "" \
  "| Check | Result |" "|---|---|" \
  "| \`characters_api.g.dart\` sha256 (Bazel = build_runner when EQUAL above) | \`$sha\` |" \
  "| lines naming \`_CharactersApi\` in it | $generated |" \
  "| retrofit action runs \`@rules_dart//dart/ext/retrofit:shim\` | $([[ $shim -gt 0 ]] && echo yes || echo no) |" \
  "| retrofit action: \`--summary\` args / envelope summary among them / \`sky_engine\` mentions | $summaries / $envelope_sum / $sky |"
ok=1
[[ $rc -eq 0 ]] || ok=0
[[ "$generated" -gt 0 && "$shim" -gt 0 && "$summaries" -gt 0 && "$envelope_sum" -gt 0 && "$sky" -eq 0 ]] || ok=0
finish T-0027-AC1 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
