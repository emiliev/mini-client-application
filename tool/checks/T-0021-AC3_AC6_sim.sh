#!/bin/bash
# T-0021-AC3 / AC6 (and the on-device half of AC4): build
# //app/mini_client:mini_client_ios for the simulator, check the bundle (Inter
# in FontManifest.json, the bundled app_config.json, the URL scheme), install
# it on a private `mc-T-0021-<role>-<pid>` simulator and take screenshots
# (at most 1200 px tall):
#   ac6-home.png         launch → the home placeholder in Inter
#   ac3-openurl-warm.png `simctl openurl <udid> miniclient://app/placeholder/42`
#                        while the app runs → that route
#   ac4-openurl-cold.png the app terminated, then `openurl …/placeholder/7`
#                        (a cold-start link) → that route after boot
# On iOS 26.2 every `simctl openurl` of a custom scheme first shows the
# system prompt "Open in “Mini Client”?" (F-0020), and simctl cannot tap it,
# so the two openurl screenshots show that prompt and AC3 is not decided
# here; the verdict covers AC6 only. The simulator is always deleted.
#   [MC_OUTPUT_BASE=/tmp/mc-ob-…] tool/checks/T-0021-AC3_AC6_sim.sh [--role engineer|verifier] [--out FILE]
# Screenshots go next to FILE, or into a temp dir whose path is printed.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BUNDLE_ID=com.emiliev.miniclient
TARGET=//app/mini_client:mini_client_ios
TMP="$(mktemp -d)"
SHOT_DIR="${OUT:+$(dirname "$OUT")}"; SHOT_DIR="${SHOT_DIR:-$TMP}"
mkdir -p "$SHOT_DIR"
UDID=""
cleanup() {
  if [[ -n "$UDID" ]]; then
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
    xcrun simctl delete "$UDID" >/dev/null 2>&1 && echo "SIMULATOR_DELETED $UDID" >&2
  fi
  [[ "$SHOT_DIR" == "$TMP" ]] || rm -rf "$TMP"
}
trap cleanup EXIT

bz() {  # Bazel, in MC_OUTPUT_BASE if set (one output base per fleet agent)
  if [[ -n "${MC_OUTPUT_BASE:-}" ]]; then "$BAZELW" --output_base="$MC_OUTPUT_BASE" "$@"
  else "$BAZELW" "$@"; fi
}

shot() {  # shot <name>: screenshot, downscaled to at most 1200 px tall
  xcrun simctl io "$UDID" screenshot "$TMP/raw.png" >/dev/null 2>&1
  local h
  h=$(sips -g pixelHeight "$TMP/raw.png" 2>/dev/null | awk '/pixelHeight/{print $2}')
  if [[ "${h:-0}" -gt 1200 ]]; then sips -Z 1200 "$TMP/raw.png" --out "$SHOT_DIR/$1" >/dev/null
  else cp "$TMP/raw.png" "$SHOT_DIR/$1"; fi
  report "- screenshot \`$1\` (original height ${h:-?} px)"
}

running() {
  xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -c "$BUNDLE_ID" || true
}

bz build --config=sim "$TARGET" > "$TMP/build.log" 2>&1; rc_build=$?
built=$(plain "$TMP/build.log" | grep -a -E 'Build completed|ERROR' | tail -1)
report "# T-0021-AC3 / AC6: simulator build, launch and deep links" "" \
  "- build \`--config=sim $TARGET\`: exit $rc_build ($built)"
[[ $rc_build -eq 0 ]] || finish T-0021-AC3_AC6 1
mkdir -p "$TMP/ipa"
IPA="$(bz info execution_root 2>/dev/null)/$(bz cquery --config=sim --output=files "$TARGET" 2>/dev/null | grep '\.ipa$')"
unzip -q "$IPA" -d "$TMP/ipa" || { report "- no ipa at \`$IPA\`"; finish T-0021-AC3_AC6 1; }
APP=$(ls -d "$TMP"/ipa/Payload/*.app)

# Bundle checks: Inter (P-031), the config asset (R13), the URL scheme.
fonts=$(cat "$APP/flutter_assets/FontManifest.json" 2>/dev/null)
inter=0; [[ "$fonts" == *'"family":"packages/mc_ds_theme/Inter"'* ]] && inter=1
inter_files=$(ls "$APP"/flutter_assets/packages/mc_ds_theme/assets/fonts/Inter-*.ttf 2>/dev/null | wc -l | tr -d ' ')
config_env=$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["env"])' \
  "$APP/flutter_assets/assets/app_config.json" 2>/dev/null)
scheme=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$APP/Info.plist" 2>/dev/null)
deeplink=$(/usr/libexec/PlistBuddy -c "Print :FlutterDeepLinkingEnabled" "$APP/Info.plist" 2>/dev/null)
report "- FontManifest has \`packages/mc_ds_theme/Inter\`: $inter; Inter .ttf files bundled: $inter_files" \
  "- bundled \`assets/app_config.json\` env: \`${config_env:-missing}\`" \
  "- Info.plist: URL scheme \`${scheme:-missing}\`, FlutterDeepLinkingEnabled \`${deeplink:-missing}\`"

NAME="mc-T-0021-$ROLE-$$"
UDID=$(xcrun simctl create "$NAME" "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-2) || finish T-0021-AC3_AC6 1
xcrun simctl boot "$UDID" && xcrun simctl bootstatus "$UDID" -b >/dev/null
# A fresh device shows system banners for a while (F-0009 gotcha 5).
sleep 20
xcrun simctl install "$UDID" "$APP"
launch=$(xcrun simctl launch "$UDID" "$BUNDLE_ID" 2>&1); rc_launch=$?
sleep 10
run_home=$(running)
shot ac6-home.png

rc_warm=0
xcrun simctl openurl "$UDID" "miniclient://app/placeholder/42" || rc_warm=$?
sleep 5
shot ac3-openurl-warm.png

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1
sleep 3
rc_cold=0
xcrun simctl openurl "$UDID" "miniclient://app/placeholder/7" || rc_cold=$?
sleep 10
run_cold=$(running)
shot ac4-openurl-cold.png

report "- simulator: \`$NAME\` ($UDID), iPhone 17 Pro, iOS 26.2; deleted on exit" \
  "- app: $(basename "$APP"), bundle id \`$BUNDLE_ID\`" \
  "- \`simctl launch\`: exit $rc_launch ($launch); launchctl entries 10 s later: $run_home" \
  "- \`simctl openurl\` warm (placeholder/42): exit $rc_warm" \
  "- \`simctl openurl\` cold (placeholder/7, app terminated first): exit $rc_cold; launchctl entries 10 s later: $run_cold" \
  "" "The screenshots are the visual checkpoints: a reviewer must look at them." \
  "AC3 (openurl screenshots): expected to show the iOS \"Open in “Mini Client”?\" prompt (F-0020); not decided by this script."
ok=0
[[ $inter -eq 1 && "$inter_files" -eq 4 && -n "$config_env" && "$scheme" == miniclient && "$deeplink" == true \
  && $rc_launch -eq 0 && "$run_home" -ge 1 && $rc_warm -eq 0 && $rc_cold -eq 0 \
  && -s "$SHOT_DIR/ac6-home.png" && -s "$SHOT_DIR/ac3-openurl-warm.png" && -s "$SHOT_DIR/ac4-openurl-cold.png" ]] && ok=1
finish T-0021-AC6 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
