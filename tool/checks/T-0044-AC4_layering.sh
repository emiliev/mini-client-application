#!/bin/bash
# T-0044-AC4: mc_ds_inputs depends on neither mc_feature_flow nor mc_paging.
# Successor of T-0040-AC3_layering.sh, which stays the check for
# mc_ds_navigation and is re-run here (so one command covers both packages).
#   1. T-0040-AC3 re-run (mc_ds_navigation, mc_arch_check, its own controls);
#   2. the Bazel closure (cquery deps) of mc_ds_inputs' library AND both test
#      targets holds neither //utility/mc_feature_flow nor //utility/mc_paging;
#      the package's pubspec, BUILD file and Dart files name neither;
#   3. positive controls: the same query over characters_list sees BOTH
#      packages (a query that cannot see them fails the check);
#   4. negative controls: each forbidden package added to the BUILD deps, the
#      pubspec, a lib import, a test import, or an import with a trailing
#      comment is reported by the same scan; every edit is undone.
#   MC_BAZEL_STARTUP='--output_base=/tmp/mc-ob-x' tool/checks/T-0044-AC4_layering.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
PKG=utility/mc_ds_inputs
LIBS=(//utility/mc_ds_inputs:mc_ds_inputs //utility/mc_ds_inputs:inputs_test //utility/mc_ds_inputs:golden_test)
FORBIDDEN=(mc_feature_flow mc_paging)
report "# T-0044-AC4: layering" ""
bad() { rc=1; }

# --- 1. the mc_ds_navigation check, re-run -----------------------------------
nav_log="$(mktemp)"
if "$REPO/tool/checks/T-0040-AC3_layering.sh" > "$nav_log" 2>&1; then
  report "## T-0040-AC3 layering (mc_ds_navigation, mc_arch_check): PASS"
else
  report "## T-0040-AC3 layering (mc_ds_navigation, mc_arch_check): FAIL" '```' "$(tail -15 "$nav_log")" '```'; bad
fi
rm -f "$nav_log"

# --- scans -------------------------------------------------------------------
# closure_hits <label...>: forbidden labels in each closure ("QUERY RETURNED
# NOTHING" when cquery fails, so a broken query cannot pass).
closure_hits() {
  local l out hit
  for l in "$@"; do
    out="$(bzw cquery "deps($l)" 2>/dev/null | sed 's/ (.*//')"
    if [[ -z "$out" ]]; then echo "$l -> QUERY RETURNED NOTHING"; continue; fi
    hit="$(grep -E '^@?@?//utility/(mc_feature_flow|mc_paging)[:/]' <<< "$out" | sort -u | head -4 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
# source_hits: pubspec, BUILD, lib and test of the package naming a forbidden
# package. Only whole-line comments (`//...`, `#...`) are ignored, so an import
# with a trailing comment is still reported.
source_hits() {
  grep -rnE "mc_feature_flow|mc_paging" "$PKG/pubspec.yaml" "$PKG/BUILD.bazel" "$PKG/lib" "$PKG/test" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#)' || true
}

# --- 2. the closure and the sources are clean --------------------------------
hits="$(closure_hits "${LIBS[@]}")"
report "## closure of ${LIBS[*]}" '```' "forbidden in closure: ${hits:-none}" '```'
[[ -z "$hits" ]] || bad
src="$(source_hits)"
report "## pubspec, BUILD, lib and test name a forbidden package (comments aside)" '```' "${src:-none}" '```'
[[ -z "$src" ]] || bad

# --- 3. positive controls ----------------------------------------------------
cl="$(bzw cquery 'deps(//feature/characters/characters_list:characters_list)' 2>/dev/null | sed 's/ (.*//')"
has_flow="$(grep -c -E '^//utility/mc_feature_flow:' <<< "$cl")"
has_paging="$(grep -c -E '^//utility/mc_paging:' <<< "$cl")"
report "## positive control: characters_list closure holds mc_feature_flow ($has_flow targets) and mc_paging ($has_paging targets)"
[[ "$has_flow" -gt 0 && "$has_paging" -gt 0 ]] || bad

# --- 4. negative controls (each edit is undone) -------------------------------
build="$PKG/BUILD.bazel"; pub="$PKG/pubspec.yaml"
dart="$PKG/lib/src/mc_chip.dart"; tdart="$PKG/test/inputs_test.dart"
snap="$(mktemp -d)"
for f in "$build" "$pub" "$dart" "$tdart"; do cp "$f" "$f.orig"; cp "$f" "$snap/$(echo "$f" | tr / _)"; done
restore() { for f in "$build" "$pub" "$dart" "$tdart"; do [[ -f "$f.orig" ]] && mv -f "$f.orig" "$f"; done; }
trap restore EXIT
neg=()
for F in "${FORBIDDEN[@]}"; do
  sed -i '' "s|^    \"//utility/mc_ds_theme\",\$|    \"//utility/mc_ds_theme\",\n    \"//utility/$F\",|" "$build"
  r="$(closure_hits //utility/mc_ds_inputs:mc_ds_inputs)"; neg+=("$F BUILD dep (closure):   ${r:-NOT DETECTED}")
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
restore; trap - EXIT
report "## negative controls (each must be reported)" '```' "${neg[@]}" '```'
for n in "${neg[@]}"; do
  [[ "$n" != *"NOT DETECTED"* && "$n" != *"QUERY RETURNED NOTHING"* ]] || bad
done
for f in "$build" "$pub" "$dart" "$tdart"; do
  if ! cmp -s "$f" "$snap/$(echo "$f" | tr / _)" || [[ -e "$f.orig" ]]; then
    report "## RESTORE FAILED: $f differs from its snapshot after the controls"; bad
  fi
done
rm -rf "$snap"
finish T-0044-AC4-layering $rc
