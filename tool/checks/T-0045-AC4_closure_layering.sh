#!/bin/bash
# T-0045-AC4: mc_forms is pure Dart, and mc_ds_forms does not depend on
# mc_feature_flow.
#   1. the Bazel closure (cquery deps) of //utility/mc_forms:mc_forms has no
#      Flutter marker and is non-empty (a query that returns nothing fails);
#   2. the closure of //utility/mc_ds_forms (library and both tests) has no
#      //utility/mc_feature_flow, and the package's BUILD file, pubspec and Dart
#      files name none (whole-line comments aside);
#   3. positive controls: //utility/mc_ds_forms:mc_ds_forms DOES show Flutter
#      markers and //utility/mc_forms (so the Flutter check can see Flutter, and
#      mc_forms is pure inside a Flutter closure); characters_list's closure
#      shows mc_feature_flow (so the layering query can see it);
#   4. negative controls (each edit is undone): a Flutter dep in mc_forms'
#      BUILD, a mc_feature_flow dep in the mc_ds_forms BUILD, pubspec, a Dart
#      import, and an import followed by a trailing comment are each reported;
#      a Flutter import in mc_forms' lib fails //utility/mc_forms:purity_test;
#   5. mc_arch_check passes.
#   MC_BAZEL_STARTUP='--output_base=/tmp/mc-ob-x' tool/checks/T-0045-AC4_closure_layering.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
bad() { rc=1; }
FORMS=utility/mc_forms
DS=utility/mc_ds_forms
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
DS_TARGETS=(//utility/mc_ds_forms:mc_ds_forms //utility/mc_ds_forms:forms_test //utility/mc_ds_forms:golden_test)
report "# T-0045-AC4: closure and layering" ""

closure() { bzw cquery "deps($1)" 2>/dev/null | sed 's/ (.*//'; }

# forms_hits: Flutter markers in the closure of mc_forms (QUERY RETURNED NOTHING
# when cquery fails, so it cannot pass).
forms_hits() {
  local out; out="$(closure //utility/mc_forms:mc_forms)"
  if [[ -z "$out" ]]; then echo "QUERY RETURNED NOTHING"; return; fi
  grep -E "$FLUTTER" <<< "$out" | sort -u | head -3
}
# flow_hits <label...>: mc_feature_flow labels in the closures.
flow_hits() {
  local l out hit
  for l in "$@"; do
    out="$(closure "$l")"
    if [[ -z "$out" ]]; then echo "$l -> QUERY RETURNED NOTHING"; continue; fi
    hit="$(grep -E '^@?@?//utility/mc_feature_flow' <<< "$out" | sort -u | head -3 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
# source_hits: files of mc_ds_forms that name mc_feature_flow, comments aside.
source_hits() {
  grep -rn "mc_feature_flow" "$DS/BUILD.bazel" "$DS/pubspec.yaml" "$DS/lib" "$DS/test" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#)' || true
}

# --- 1. mc_forms is pure ------------------------------------------------------
n="$(closure //utility/mc_forms:mc_forms | grep -c .)"
h="$(forms_hits)"
report "## closure of //utility/mc_forms:mc_forms ($n targets)" '```' "Flutter markers: ${h:-none}" '```'
[[ "$n" -ge 1 && -z "$h" ]] || bad

# --- 2. mc_ds_forms does not depend on mc_feature_flow -------------------------
hits="$(flow_hits "${DS_TARGETS[@]}")"
report "## closure of ${DS_TARGETS[*]}" '```' "mc_feature_flow in closure: ${hits:-none}" '```'
[[ -z "$hits" ]] || bad
src="$(source_hits)"
report "## BUILD, pubspec, lib and test name mc_feature_flow (comments aside)" '```' "${src:-none}" '```'
[[ -z "$src" ]] || bad

# --- 3. positive controls -------------------------------------------------------
ds="$(closure //utility/mc_ds_forms:mc_ds_forms)"
ds_flutter="$(grep -E "$FLUTTER" <<< "$ds" | sort -u | head -3)"
ds_forms="$(grep -c -E '^//utility/mc_forms:' <<< "$ds")"
report "## positive control: mc_ds_forms closure" '```' "Flutter markers: ${ds_flutter:-none}" "mc_forms targets: $ds_forms" '```'
[[ -n "$ds_flutter" && "$ds_forms" -gt 0 ]] || bad
cl="$(closure //feature/characters/characters_list:characters_list)"
has_flow="$(grep -c -E '^//utility/mc_feature_flow:' <<< "$cl")"
report "## positive control: characters_list closure holds mc_feature_flow ($has_flow targets)"
[[ "$has_flow" -gt 0 ]] || bad

# --- 4. negative controls (each edit is undone) ---------------------------------
fbuild="$FORMS/BUILD.bazel"; dbuild="$DS/BUILD.bazel"; dpub="$DS/pubspec.yaml"
ddart="$DS/lib/src/mc_form_scaffold.dart"; fdart="$FORMS/lib/src/validators.dart"
for f in "$fbuild" "$dbuild" "$dpub" "$ddart" "$fdart"; do cp "$f" "$f.orig"; done
restore() { for f in "$fbuild" "$dbuild" "$dpub" "$ddart" "$fdart"; do [[ -f "$f.orig" ]] && mv -f "$f.orig" "$f"; done; }
trap restore EXIT
sed -i '' 's|^    "//utility/mc_prelude",$|    "//utility/mc_prelude",\n    "@pub_deps//:flutter",|' "$fbuild"
neg_flutter="$(forms_hits)"
cp "$fbuild.orig" "$fbuild"
sed -i '' 's|^    "//utility/mc_ds_buttons",$|    "//utility/mc_ds_buttons",\n    "//utility/mc_feature_flow",|' "$dbuild"
neg_build="$(flow_hits //utility/mc_ds_forms:mc_ds_forms)"
cp "$dbuild.orig" "$dbuild"
sed -i '' 's|^  mc_forms: any$|  mc_forms: any\n  mc_feature_flow: any|' "$dpub"
neg_pub="$(source_hits)"
cp "$dpub.orig" "$dpub"
sed -i '' "1i\\
import 'package:mc_feature_flow/mc_feature_flow.dart';
" "$ddart"
neg_dart="$(source_hits)"
cp "$ddart.orig" "$ddart"
sed -i '' "1i\\
import 'package:mc_feature_flow/mc_feature_flow.dart'; /// layering
" "$ddart"
neg_trailing="$(source_hits)"
cp "$ddart.orig" "$ddart"
sed -i '' "1i\\
import 'package:flutter/widgets.dart';
" "$fdart"
if bzw test //utility/mc_forms:purity_test > /dev/null 2>&1; then neg_purity=""; else neg_purity="purity_test failed as expected"; fi
cp "$fdart.orig" "$fdart"
restore; trap - EXIT
report "## negative controls (each must be reported)" '```' \
  "Flutter dep in mc_forms BUILD:  ${neg_flutter:-NOT DETECTED}" \
  "feature_flow dep in BUILD:      ${neg_build:-NOT DETECTED}" \
  "feature_flow dep in pubspec:    ${neg_pub:-NOT DETECTED}" \
  "feature_flow Dart import:       ${neg_dart:-NOT DETECTED}" \
  "import + trailing ///:          ${neg_trailing:-NOT DETECTED}" \
  "Flutter import in mc_forms lib: ${neg_purity:-NOT DETECTED}" '```'
for x in "$neg_flutter" "$neg_build" "$neg_pub" "$neg_dart" "$neg_trailing" "$neg_purity"; do
  [[ -n "$x" && "$x" != *"QUERY RETURNED NOTHING"* ]] || bad
done
git diff --quiet -- "$FORMS" "$DS" || { report "## RESTORE FAILED: the working tree differs"; bad; }

# --- 5. mc_arch_check ------------------------------------------------------------
if arch="$(bzw run //tool/mc_arch_check:bin 2>&1)"; then
  report "## mc_arch_check: PASS" '```' "$(tr '\r' '\n' <<< "$arch" | tail -3)" '```'
else
  report "## mc_arch_check: FAIL" '```' "$(tr '\r' '\n' <<< "$arch" | tail -10)" '```'; bad
fi
finish T-0045-AC4 $rc
