#!/bin/bash
# T-0058-AC4: no feature, wiring or utility library code opens an overlay
# directly. Overlays go through mc_ds_overlays (showMcConfirm, showMcDialog,
# showMcSheet, showMcChoiceSheet, McMenuButton, showMcToast).
#   1. scan every `lib/` Dart file under app/, feature/, utility/,
#      third_party/ and spike/ except utility/mc_ds_overlays for showDialog,
#      showAdaptiveDialog, showModalBottomSheet, showBottomSheet,
#      showGeneralDialog, showCupertinoDialog, showCupertinoModalPopup,
#      showCupertinoSheet, showSnackBar, showMaterialBanner, showAboutDialog,
#      showLicensePage, showMenu, the PopupMenuButton widget and
#      `Overlay.of(...).insert`. Whole-line comments (`//`, `///`) are ignored, so a doc that
#      names one is fine. Tests are out of scope: they drive Flutter's own
#      API on purpose (T-0048, T-0054).
#   2. positive control: the same scan over utility/mc_ds_overlays/lib finds
#      the calls (a scan that cannot see them fails the check).
#   3. negative controls: each forbidden call planted in a throwaway feature
#      lib file is reported; whole-line comments are not; the file is removed.
#   tool/checks/T-0058-AC4_no_direct_overlays.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
CALLS='showDialog|showAdaptiveDialog|showModalBottomSheet|showBottomSheet|showGeneralDialog|showCupertinoDialog|showCupertinoModalPopup|showCupertinoSheet|showSnackBar|showMaterialBanner|showAboutDialog|showLicensePage|showMenu|PopupMenuButton|Overlay\.of\([^)]*\)\.insert'
PROBE="feature/characters/characters_list/lib/t0058_probe.dart"
report "# T-0058-AC4: no direct overlay calls" ""

# libdirs: every lib/ directory of every package except mc_ds_overlays.
libdirs() {
  find app feature utility third_party spike -type d -name lib \
    -not -path 'utility/mc_ds_overlays/*' 2>/dev/null
}
# scan <dir...>: "file:line:text" for every call outside a whole-line comment.
scan() {
  { grep -rnE "\b($CALLS)\b" --include='*.dart' "$@" 2>/dev/null || true; } \
    | { grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true; }
}
scan_all() { libdirs | xargs grep -rnE "\b($CALLS)\b" --include='*.dart' 2>/dev/null \
    | { grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true; }; }

# --- 1. the scan -------------------------------------------------------------
hits="$(scan_all)"
report "## direct calls in lib code (outside mc_ds_overlays)" '```' "${hits:-none}" '```'
[[ -z "$hits" ]] || rc=1

# --- 2. positive control -----------------------------------------------------
pos="$(scan utility/mc_ds_overlays/lib | cut -d: -f1 | sort -u | tr '\n' ' ')"
report "## positive control: mc_ds_overlays/lib holds the calls in: ${pos:-NOTHING}"
[[ -n "$pos" ]] || rc=1

# --- 3. negative controls ----------------------------------------------------
neg=()
trap 'rm -f "$PROBE"' EXIT
PROBES=(
  'showDialog(context: ctx);'
  'showAdaptiveDialog(context: ctx);'
  'showModalBottomSheet(context: ctx);'
  'showBottomSheet(context: ctx);'
  'showGeneralDialog(context: ctx);'
  'showCupertinoDialog(context: ctx);'
  'showCupertinoModalPopup(context: ctx);'
  'showCupertinoSheet(context: ctx);'
  'showSnackBar(null);'
  'showMaterialBanner(null);'
  'showAboutDialog(context: ctx);'
  'showLicensePage(context: ctx);'
  'showMenu(context: ctx);'
  'PopupMenuButton<int>(itemBuilder: b);'
  'Overlay.of(ctx).insert(entry);'
)
for c in "${PROBES[@]}"; do
  printf "void f(dynamic ctx) {\n  %s\n}\n" "$c" > "$PROBE"
  if scan_all | grep -q t0058_probe; then neg+=("$c: reported"); else neg+=("$c: NOT DETECTED"); fi
done
printf "// showDialog(context: ctx)\n/// showSnackBar and PopupMenuButton are named in a doc\nvoid f() {}\n" > "$PROBE"
if scan_all | grep -q t0058_probe; then neg+=("whole-line comments: WRONGLY REPORTED"); else neg+=("whole-line comments: ignored"); fi
rm -f "$PROBE"; trap - EXIT
report "## negative controls" '```' "${neg[@]}" '```'
for n in "${neg[@]}"; do
  [[ "$n" != *"NOT DETECTED"* && "$n" != *"WRONGLY"* ]] || rc=1
done
[[ ! -e "$PROBE" ]] || { report "## PROBE NOT REMOVED: $PROBE"; rc=1; }
finish T-0058-AC4-no-direct-overlays $rc
