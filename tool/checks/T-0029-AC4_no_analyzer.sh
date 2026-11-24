#!/bin/bash
# T-0029-AC4: the BDD test's closure has no analyzer and no bdd_widget_test
# (no runtime dependency on the generator, plan 03 X2), and a data-table
# feature compiles against mc_test_steps' DataTable.
#   tool/checks/T-0029-AC4_no_analyzer.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BZ=("$BAZELW")
[[ -n "${MC_OUTPUT_BASE:-}" ]] && BZ+=("--output_base=$MC_OUTPUT_BASE")
rc=0
target=//spike/bdd_sample:bdd_test
GEN='bdd_widget_test|ext_pub_deps__build//|ext_pub_deps__analyzer//|_fe_analyzer_shared|:analyzer( |$)'
report "# T-0029-AC4: no analyzer in :bdd_test; DataTable from mc_test_steps" ""

runtime="$("${BZ[@]}" cquery "deps($target)" --notool_deps 2>/dev/null)"
n="$(wc -l <<< "$runtime" | tr -d ' ')"
hits="$(grep -E "$GEN" <<< "$runtime" | head -5)"
report "## \`cquery 'deps($target)' --notool_deps\` ($n targets)" '```' \
  "analyzer / build / bdd_widget_test: ${hits:-none}" '```'
if [[ "$n" -le 100 ]]; then report "- FAIL: the runtime closure has only $n targets (cquery failed?)"; rc=1; fi
if [[ -n "$hits" ]]; then report "- FAIL: analyzer, build or bdd_widget_test is in the runtime closure"; rc=1; fi

all="$("${BZ[@]}" cquery "deps($target)" 2>/dev/null)"
gen_cfg="$(grep -E '^@rules_dart//dart/ext/bdd:generator ' <<< "$all" | sed 's/.*(\(.*\))/\1/')"
test_cfg="$(grep -E "^$target " <<< "$all" | sed 's/.*(\(.*\))/\1/')"
analyzer_cfgs="$(grep -E "$GEN" <<< "$all" | grep -v '(null)' | sed 's/.*(\(.*\))/\1/' | sort -u | tr '\n' ' ')"
report "## \`cquery 'deps($target)'\` with tool deps ($(wc -l <<< "$all" | tr -d ' ') targets)" \
  "- the test is in configuration \`$test_cfg\`; the generator (a build tool) in \`$gen_cfg\`" \
  "- analyzer / build / bdd_widget_test targets are only in: \`${analyzer_cfgs:-none}\`" \
  "  (the generator formats its output with dart_style, which depends on analyzer;" \
  "  none of it is compiled into or linked with the test)"
if [[ -z "$gen_cfg" || "$gen_cfg" == "$test_cfg" ]]; then
  report "- FAIL: the generator is not in its own (exec) configuration"; rc=1
elif [[ -n "$analyzer_cfgs" && "$analyzer_cfgs" != "$gen_cfg " ]]; then
  report "- FAIL: analyzer, build or bdd_widget_test is in a configuration other than the generator's"; rc=1
fi

gen="$("${BZ[@]}" info bazel-bin 2>/dev/null)/spike/bdd_sample/test/feature/greeting_table_test.dart"
"${BZ[@]}" build "$target" > /dev/null 2>&1 || { report "- FAIL: $target does not build"; rc=1; }
report "## Data table: \`greeting_table_test.dart\` (generated)" '```dart' "$(grep -nE "import|DataTable" "$gen")" '```'
grep -q "import 'package:mc_test_steps/mc_test_steps.dart' as bdd;" "$gen" || { report "- FAIL: DataTable not from mc_test_steps"; rc=1; }
grep -q "const bdd.DataTable(" "$gen" || { report "- FAIL: no DataTable argument"; rc=1; }
! grep -q "bdd_widget_test" "$gen" || { report "- FAIL: the generated test imports bdd_widget_test"; rc=1; }
[[ -n "$OUT" ]] && sed 's/ (.*//' <<< "$runtime" | sort > "$(dirname "$OUT")/T-0029-AC4_cquery_notool_deps.txt"
[[ -n "$OUT" ]] && grep -E "$GEN" <<< "$all" | grep -v '(null)' > "$(dirname "$OUT")/T-0029-AC4_tool_closure_generator_targets.txt"
finish T-0029-AC4 $rc
