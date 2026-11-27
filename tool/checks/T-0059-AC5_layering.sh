#!/bin/bash
# T-0059-AC5: mc_ds_charts depends only on mc_ds_theme, mc_ds_layout,
# mc_ds_tokens and mc_ds_feedback (for McEmptyView; feedback brings
# mc_ds_buttons), and nothing below it depends back on it.
#   1. mc_arch_check passes on the workspace;
#   2. the Bazel closure (cquery deps) of the LIBRARY holds, among
#      //utility/* packages, only the allowed ones; the closure of each test
#      target holds only those plus mc_test_utils (the golden harness);
#   3. the package's pubspec dependencies, BUILD deps and `package:mc_*`
#      imports name only allowed packages (comments aside);
#   4. no lower DS package (theme, layout, tokens, feedback, buttons) names
#      mc_ds_charts (no cycle);
#   5. positive controls: the closure query sees mc_ds_feedback and
#      mc_ds_buttons (so it can see packages at all), and characters_list sees
#      mc_paging;
#   6. negative controls: a forbidden package added to the BUILD deps, the
#      pubspec, a lib import, an import with a trailing comment, or a test
#      import is reported by the same scan; every edit is undone.
#   MC_BAZEL_STARTUP='--output_base=/tmp/mc-ob-x' tool/checks/T-0059-AC5_layering.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
PKG=utility/mc_ds_charts
LIB=//utility/mc_ds_charts:mc_ds_charts
TESTS=(//utility/mc_ds_charts:geometry_test //utility/mc_ds_charts:painter_test //utility/mc_ds_charts:charts_test //utility/mc_ds_charts:golden_test)
# Allowed utility packages in the closure of the library.
ALLOWED_LIB='mc_ds_charts|mc_ds_feedback|mc_ds_buttons|mc_ds_layout|mc_ds_theme|mc_ds_tokens'
# Tests may also use the golden harness.
ALLOWED_TEST="$ALLOWED_LIB|mc_test_utils"
# Packages the pubspec, BUILD file and Dart files may name.
ALLOWED_DIRECT='mc_ds_charts|mc_ds_feedback|mc_ds_layout|mc_ds_theme|mc_ds_tokens|mc_test_utils'
report "# T-0059-AC5: layering" ""
bad() { rc=1; }

# --- 1. mc_arch_check --------------------------------------------------------
if arch="$(bzw run //tool/mc_arch_check:bin 2>&1)"; then
  report "## mc_arch_check: PASS" '```' "$(tr '\r' '\n' <<< "$arch" | tail -3)" '```'
else
  report "## mc_arch_check: FAIL" '```' "$(tr '\r' '\n' <<< "$arch" | tail -10)" '```'; bad
fi

# --- scans -------------------------------------------------------------------
# closure_hits <allowed-regex> <label...>: //utility packages in each closure
# that are not allowed ("QUERY RETURNED NOTHING" when cquery fails, so a broken
# query cannot pass).
closure_hits() {
  local allowed="$1" l out hit; shift
  for l in "$@"; do
    out="$(bzw cquery "deps($l)" 2>/dev/null | sed 's/ (.*//')"
    if [[ -z "$out" ]]; then echo "$l -> QUERY RETURNED NOTHING"; continue; fi
    hit="$(grep -E '^@?@?//(utility|feature|app|spike)/' <<< "$out" \
      | sed -E 's#^@?@?//([^:]+):.*#\1#' | sort -u \
      | grep -vE "^utility/($allowed)\$" | head -6 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
# source_hits: any mc_* package other than the allowed ones named in the
# package's pubspec, BUILD or Dart files. Whole-line comments (`//...`, `#...`)
# are ignored, so an import with a trailing comment is still reported.
source_hits() {
  {
    grep -nE '^  mc_[a-z_]+:' "$PKG/pubspec.yaml" 2>/dev/null \
      | sed -E "s#^([0-9]+):  (mc_[a-z_]+):.*#pubspec:\1:\2#"
    grep -nE '"//utility/mc_[a-z_]+' "$PKG/BUILD.bazel" 2>/dev/null \
      | sed -E "s#^([0-9]+):.*//utility/(mc_[a-z_]+).*#BUILD:\1:\2#"
    grep -rnE 'package:mc_[a-z_]+/' "$PKG/lib" "$PKG/test" 2>/dev/null \
      | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#)' \
      | sed -E "s#^([^:]+:[0-9]+):.*package:(mc_[a-z_]+)/.*#\1:\2#"
  } | grep -vE ":($ALLOWED_DIRECT)\$" || true
}
# cycle_hits: lower DS packages that name mc_ds_charts.
cycle_hits() {
  grep -rn "mc_ds_charts" utility/mc_ds_theme utility/mc_ds_layout utility/mc_ds_tokens \
    utility/mc_ds_feedback utility/mc_ds_buttons --include=pubspec.yaml --include=BUILD.bazel --include='*.dart' 2>/dev/null || true
}

# --- 2/3/4. the closure, the sources and the lower layers are clean ----------
hits="$(closure_hits "$ALLOWED_LIB" "$LIB")"
report "## closure of the library" '```' "unexpected in closure: ${hits:-none}" '```'
[[ -z "$hits" ]] || bad
hits="$(closure_hits "$ALLOWED_TEST" "${TESTS[@]}")"
report "## closure of the test targets" '```' "unexpected in closure: ${hits:-none}" '```'
[[ -z "$hits" ]] || bad
src="$(source_hits)"
report "## pubspec, BUILD and Dart files name a package outside the allowed set" '```' "${src:-none}" '```'
[[ -z "$src" ]] || bad
cyc="$(cycle_hits)"
report "## lower DS packages naming mc_ds_charts" '```' "${cyc:-none}" '```'
[[ -z "$cyc" ]] || bad

# --- 5. positive controls ----------------------------------------------------
cl="$(bzw cquery "deps($LIB)" 2>/dev/null | sed 's/ (.*//')"
has_fb="$(grep -c -E '^//utility/mc_ds_feedback:' <<< "$cl")"
has_bt="$(grep -c -E '^//utility/mc_ds_buttons:' <<< "$cl")"
report "## positive control: the library closure holds mc_ds_feedback ($has_fb targets) and mc_ds_buttons ($has_bt targets)"
[[ "$has_fb" -gt 0 && "$has_bt" -gt 0 ]] || bad
cl2="$(bzw cquery 'deps(//feature/characters/characters_list:characters_list)' 2>/dev/null | sed 's/ (.*//')"
has_paging="$(grep -c -E '^//utility/mc_paging:' <<< "$cl2")"
report "## positive control: characters_list closure holds mc_paging ($has_paging targets), which the allowed set does not"
[[ "$has_paging" -gt 0 ]] || bad
pos="$(closure_hits "$ALLOWED_LIB" //feature/characters/characters_list:characters_list)"
report "## positive control: the scan flags characters_list" '```' "${pos:-NOT DETECTED}" '```'
[[ -n "$pos" ]] || bad

# --- 6. negative controls (each edit is undone) -------------------------------
build="$PKG/BUILD.bazel"; pub="$PKG/pubspec.yaml"
dart="$PKG/lib/src/chart_common.dart"; tdart="$PKG/test/charts_test.dart"
lower=utility/mc_ds_layout/pubspec.yaml
FILES=("$build" "$pub" "$dart" "$tdart" "$lower")
snap="$(mktemp -d)"
for f in "${FILES[@]}"; do cp "$f" "$f.orig"; cp "$f" "$snap/$(echo "$f" | tr / _)"; done
restore() { for f in "${FILES[@]}"; do [[ -f "$f.orig" ]] && mv -f "$f.orig" "$f"; done; }
trap restore EXIT
neg=()
for F in mc_paging mc_feature_flow mc_ds_inputs; do
  sed -i '' "s|^    \"//utility/mc_ds_theme\",\$|    \"//utility/mc_ds_theme\",\n    \"//utility/$F\",|" "$build"
  r="$(closure_hits "$ALLOWED_LIB" "$LIB")"; neg+=("$F BUILD dep (closure):   ${r:-NOT DETECTED}")
  r="$(source_hits)"; neg+=("$F BUILD dep (scan):      ${r:-NOT DETECTED}")
  cp "$build.orig" "$build"
  sed -i '' "s|^  mc_ds_theme: any\$|  mc_ds_theme: any\n  $F: any|" "$pub"
  r="$(source_hits)"; neg+=("$F pubspec dep:         ${r:-NOT DETECTED}")
  cp "$pub.orig" "$pub"
  sed -i '' "1i\\
import 'package:$F/$F.dart';
" "$dart"
  r="$(source_hits)"; neg+=("$F lib import:          ${r:-NOT DETECTED}")
  cp "$dart.orig" "$dart"
  sed -i '' "1i\\
import 'package:$F/$F.dart'; /// layering
" "$dart"
  r="$(source_hits)"; neg+=("$F import + trailing ///: ${r:-NOT DETECTED}")
  cp "$dart.orig" "$dart"
  sed -i '' "1i\\
import 'package:$F/$F.dart';
" "$tdart"
  r="$(source_hits)"; neg+=("$F test import:         ${r:-NOT DETECTED}")
  cp "$tdart.orig" "$tdart"
done
# a lower layer naming mc_ds_charts (a cycle) is reported
sed -i '' 's|^  mc_ds_tokens: any$|  mc_ds_tokens: any\n  mc_ds_charts: any|' "$lower"
r="$(cycle_hits)"; neg+=("mc_ds_layout -> mc_ds_charts (cycle): ${r:-NOT DETECTED}")
cp "$lower.orig" "$lower"
restore; trap - EXIT
report "## negative controls (each must be reported)" '```' "${neg[@]}" '```'
for n in "${neg[@]}"; do
  [[ "$n" != *"NOT DETECTED"* && "$n" != *"QUERY RETURNED NOTHING"* ]] || bad
done
for f in "${FILES[@]}"; do
  if [[ -e "$f.orig" ]] || ! cmp -s "$f" "$snap/$(echo "$f" | tr / _)"; then
    report "## RESTORE FAILED: $f differs from its snapshot after the controls"; bad
  fi
done
rm -rf "$snap"
finish T-0059-AC5-layering $rc
