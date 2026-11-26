#!/bin/bash
# T-0040-AC3: mc_ds_navigation does not depend on mc_feature_flow, and
# characters_list wires McAppBar with McFlowBackButton in its leading.
#   1. mc_arch_check passes on the workspace;
#   2. the Bazel closure (cquery deps) of the library AND both test targets of
#      mc_ds_navigation has no //utility/mc_feature_flow, and its pubspec and
#      Dart imports name no mc_feature_flow;
#   3. positive controls: the same query over characters_list sees BOTH
#      mc_feature_flow and mc_ds_navigation (a query that cannot see a package
#      fails the check);
#   4. negative controls: a mc_feature_flow dep added to the BUILD file, to
#      the pubspec, or to a Dart import is each reported by the same scan;
#   5. characters_list's page source uses McAppBar with McFlowBackButton.
#   MC_BAZEL_STARTUP='--output_base=/tmp/mc-ob-x' tool/checks/T-0040-AC3_layering.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
PKG=utility/mc_ds_navigation
LIBS=(//utility/mc_ds_navigation:mc_ds_navigation //utility/mc_ds_navigation:navigation_test //utility/mc_ds_navigation:golden_test)
report "# T-0040-AC3: layering" ""

bad() { rc=1; }

# --- 1. mc_arch_check --------------------------------------------------------
if arch="$(bzw run //tool/mc_arch_check:bin 2>&1)"; then
  report "## mc_arch_check: PASS" '```' "$(tr '\r' '\n' <<< "$arch" | tail -3)" '```'
else
  report "## mc_arch_check: FAIL" '```' "$(tr '\r' '\n' <<< "$arch" | tail -10)" '```'; bad
fi

# --- scans -------------------------------------------------------------------
# closure_hits <label...>: prints the mc_feature_flow labels in the closure of
# each label ("QUERY RETURNED NOTHING" when cquery fails, so it cannot pass).
closure_hits() {
  local l out hit
  for l in "$@"; do
    out="$(bzw cquery "deps($l)" 2>/dev/null | sed 's/ (.*//')"
    if [[ -z "$out" ]]; then echo "$l -> QUERY RETURNED NOTHING"; continue; fi
    hit="$(grep -E '^@?@?//utility/mc_feature_flow' <<< "$out" | sort -u | head -3 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
# source_hits: pubspec and Dart files of the package that name mc_feature_flow.
#   - every utility/mc_ds_* pubspec (a dependency declared there and nowhere
#     else still breaks the layering), and every mc_ds_* BUILD file;
#   - mc_ds_navigation's Dart files.
# Only whole-line comments (`//...`, `#...`) are ignored, so an import with a
# trailing comment is still reported.
source_hits() {
  grep -rn "mc_feature_flow" utility/mc_ds_*/pubspec.yaml utility/mc_ds_*/BUILD.bazel \
    "$PKG/lib" "$PKG/test" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#)' || true
}

# --- 2. the closure and the sources are clean --------------------------------
hits="$(closure_hits "${LIBS[@]}")"
report "## closure of ${LIBS[*]}" '```' "mc_feature_flow in closure: ${hits:-none}" '```'
[[ -z "$hits" ]] || bad
src="$(source_hits)"
report "## pubspec, lib and test name mc_feature_flow (comments aside)" '```' "${src:-none}" '```'
[[ -z "$src" ]] || bad

# --- 3. positive controls ----------------------------------------------------
cl="$(bzw cquery 'deps(//feature/characters/characters_list:characters_list)' 2>/dev/null | sed 's/ (.*//')"
has_flow="$(grep -c -E '^//utility/mc_feature_flow:' <<< "$cl")"
has_nav="$(grep -c -E '^//utility/mc_ds_navigation:' <<< "$cl")"
report "## positive control: characters_list closure holds mc_feature_flow ($has_flow targets) and mc_ds_navigation ($has_nav targets)"
[[ "$has_flow" -gt 0 && "$has_nav" -gt 0 ]] || bad

# --- 4. negative controls (each edit is undone) -------------------------------
build="$PKG/BUILD.bazel"; pub="$PKG/pubspec.yaml"; dart="$PKG/lib/src/mc_tab_bar.dart"
cp "$build" "$build.orig"; cp "$pub" "$pub.orig"; cp "$dart" "$dart.orig"
restore() { mv -f "$build.orig" "$build"; mv -f "$pub.orig" "$pub"; mv -f "$dart.orig" "$dart"; }
trap restore EXIT
sed -i '' 's|^    "//utility/mc_ds_theme",$|    "//utility/mc_ds_theme",\n    "//utility/mc_feature_flow",|' "$build"
neg_build="$(closure_hits //utility/mc_ds_navigation:mc_ds_navigation)"
cp "$build.orig" "$build"
sed -i '' 's|^  mc_ds_theme: any$|  mc_ds_theme: any\n  mc_feature_flow: any|' "$pub"
neg_pub="$(source_hits)"
cp "$pub.orig" "$pub"
sed -i '' "1i\\
import 'package:mc_feature_flow/mc_feature_flow.dart';
" "$dart"
neg_dart="$(source_hits)"
cp "$dart.orig" "$dart"
# An import with a trailing doc comment must not be hidden by a line filter.
sed -i '' "1i\\
import 'package:mc_feature_flow/mc_feature_flow.dart'; /// layering
" "$dart"
neg_trailing="$(source_hits)"
cp "$dart.orig" "$dart"
# A dependency declared only in the pubspec of ANOTHER mc_ds_* package.
other_pub=utility/mc_ds_buttons/pubspec.yaml
other_build=utility/mc_ds_buttons/BUILD.bazel
cp "$other_pub" "$other_pub.orig"; cp "$other_build" "$other_build.orig"
restore_other() { mv -f "$other_pub.orig" "$other_pub"; mv -f "$other_build.orig" "$other_build"; }
trap 'restore; restore_other' EXIT
sed -i '' 's|^  mc_ds_theme: any$|  mc_ds_theme: any\n  mc_feature_flow: any|' "$other_pub"
neg_other_pub="$(source_hits)"
cp "$other_pub.orig" "$other_pub"
sed -i '' 's|^    "//utility/mc_ds_theme",$|    "//utility/mc_ds_theme",\n    "//utility/mc_feature_flow",|' "$other_build"
neg_other_build="$(source_hits)"
restore_other
restore; trap - EXIT
report "## negative controls (each must be reported)" '```' \
  "BUILD dep:               ${neg_build:-NOT DETECTED}" \
  "pubspec dep:             ${neg_pub:-NOT DETECTED}" \
  "Dart import:             ${neg_dart:-NOT DETECTED}" \
  "import + trailing ///:   ${neg_trailing:-NOT DETECTED}" \
  "other ds pubspec only:   ${neg_other_pub:-NOT DETECTED}" \
  "other ds BUILD only:     ${neg_other_build:-NOT DETECTED}" '```'
for n in "$neg_build" "$neg_pub" "$neg_dart" "$neg_trailing" "$neg_other_pub" "$neg_other_build"; do
  [[ -n "$n" && "$n" != *"QUERY RETURNED NOTHING"* ]] || bad
done

# --- 5. characters_list wires the leading ------------------------------------
page=feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart
if grep -q "McAppBar(" "$page" && grep -q "leading: const McFlowBackButton()" "$page" \
   && ! grep -qE "\bAppBar\(" <(grep -v "McAppBar(" "$page"); then
  report "## characters_list page: McAppBar with leading McFlowBackButton: PASS"
else
  report "## characters_list page: McAppBar with leading McFlowBackButton: FAIL"; bad
fi
finish T-0040-AC3 $rc
