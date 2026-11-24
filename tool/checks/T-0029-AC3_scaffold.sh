#!/bin/bash
# T-0029-AC3: `bazel run //tool/bdd:scaffold` writes a stub for each missing
# step into test/feature/step/, and leaves existing steps alone. Runs on a
# copy of spike/bdd_sample in a temp workspace (`--workspace`), so the real
# tree is never touched.
#   tool/checks/T-0029-AC3_scaffold.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BZ=("$BAZELW")
[[ -n "${MC_OUTPUT_BASE:-}" ]] && BZ+=("--output_base=$MC_OUTPUT_BASE")
rc=0
report "# T-0029-AC3: scaffold writes step stubs" ""
ws="$(mktemp -d)"
trap 'rm -rf "$ws"' EXIT
mkdir -p "$ws/spike" "$ws/utility/mc_test_steps/lib"
cp -R spike/bdd_sample "$ws/spike/"
rm -rf "$ws/spike/bdd_sample/test/negative"
cp -R utility/mc_test_steps/lib/src "$ws/utility/mc_test_steps/lib/"
existing="$ws/spike/bdd_sample/test/feature/step/i_open_the_greeting.dart"
sum_before="$(shasum < "$existing")"
cat > "$ws/spike/bdd_sample/test/feature/greeting_new.feature" <<'FEATURE'
Feature: New behaviour
  Scenario: Two new steps and two known ones
    Given the backend serves {'greeting.basic'}
    When I open the greeting
    And I wave {2} times
    Then the greeting rows are
      | 'text' |
      | 'Hi'   |
FEATURE
log="$(mktemp)"
"${BZ[@]}" run //tool/bdd:scaffold -- --workspace "$ws" //spike/bdd_sample > "$log" 2>&1
code=$?
report "\`tool/bazelw run //tool/bdd:scaffold -- --workspace <tmp> //spike/bdd_sample\` (exit $code)" '```' \
  "$(plain "$log" | grep '^scaffold:')" '```'
[[ $code == 0 ]] || rc=1
step="$ws/spike/bdd_sample/test/feature/step"
for f in i_wave_times.dart the_greeting_rows_are.dart; do
  if [[ -f "$step/$f" ]]; then
    report "### test/feature/step/$f" '```dart' "$(cat "$step/$f")" '```'
  else
    report "- FAIL: no stub test/feature/step/$f"; rc=1
  fi
done
grep -q 'Future<void> iWaveTimes(WidgetTester tester, num param1)' "$step/i_wave_times.dart" 2>/dev/null \
  || { report "- FAIL: i_wave_times.dart has the wrong signature"; rc=1; }
grep -q "import 'package:mc_test_steps/mc_test_steps.dart' as bdd;" "$step/the_greeting_rows_are.dart" 2>/dev/null \
  || { report "- FAIL: the data-table stub does not use mc_test_steps' DataTable"; rc=1; }
n="$(find "$step" -type f | wc -l | tr -d ' ')"
[[ "$n" == 3 ]] && report "- exactly 3 step files: the existing one and the 2 stubs (no stub for shared steps)" \
  || { report "- FAIL: $n step files, expected 3"; rc=1; }
[[ "$(shasum < "$existing")" == "$sum_before" ]] && report "- the existing step is unchanged" \
  || { report "- FAIL: the existing step was rewritten"; rc=1; }
"${BZ[@]}" run //tool/bdd:scaffold -- --workspace "$ws" //spike/bdd_sample > "$log" 2>&1
plain "$log" | grep -q 'every step is defined' && report "- a second run writes nothing" \
  || { report "- FAIL: the second run wrote again"; rc=1; }
rm -f "$log"
finish T-0029-AC3 $rc
