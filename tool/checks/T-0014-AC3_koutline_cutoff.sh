#!/bin/bash
# T-0014-AC3 (H-SDK): the bundled Dart is 3.13.x, a body-only edit leaves the
# `.koutline` byte-identical while the `.kmod` changes, and no stripper
# fallback diagnostic appears. Edits spike/greeting/lib/greeting.dart and always
# restores it.
#   tool/checks/T-0014-AC3_koutline_cutoff.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
SRC=spike/greeting/lib/greeting.dart
BIN=bazel-out/darwin_arm64-fastbuild/bin/spike/greeting
TMP="$(mktemp -d)"
cp "$SRC" "$TMP/greeting.dart.orig"
restore() { cp "$TMP/greeting.dart.orig" "$REPO/$SRC"; rm -rf "$TMP"; }
trap restore EXIT
digest() { [[ -d "$1" ]] && (cd "$1" && find -L . -type f | sort | xargs shasum -a 256) | shasum -a 256 | cut -c1-16; }
nfiles() { find -L "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }
# --remote_download_all: disk-cache hits are otherwise not written to bazel-out (F-0009).
test_run() { "$BAZELW" test --remote_download_all //spike/hello:widget_test > "$1" 2>&1; }

test_run "$TMP/before.log"; rc0=$?
o1=$(digest $BIN/greeting.flutter.koutline); r1=$(digest $BIN/greeting.koutline); k1=$(digest $BIN/greeting.flutter.kmod)
n1=$(nfiles $BIN/greeting.flutter.koutline)
# Body-only edit: a new statement inside greeting(); the signature is unchanged.
sed -i '' "s/^  const who = 'mini-client';$/  const who = 'mini-client';\n  assert(who.isNotEmpty, 'T-0014-AC3 body edit');/" "$SRC"
grep -q 'T-0014-AC3 body edit' "$SRC" || { report "edit did not apply"; finish T-0014-AC3 1; }
test_run "$TMP/after.log"; rc1=$?
o2=$(digest $BIN/greeting.flutter.koutline); r2=$(digest $BIN/greeting.koutline); k2=$(digest $BIN/greeting.flutter.kmod)
restore; trap - EXIT

OB="$("$BAZELW" info output_base 2>/dev/null)"
SDK="$OB/external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk"
dart_version="$(cat "$SDK/version" 2>/dev/null)"
fb_build=$(cat "$TMP/before.log" "$TMP/after.log" 2>/dev/null | grep -a -c 'falling back to unstripped dill' || true)
fb_workers=$(cat "$OB"/bazel-workers/*.log 2>/dev/null | grep -a -c 'falling back to unstripped dill' || true)

report "# T-0014-AC3: H-SDK" "" "| Check | Result |" "|---|---|" \
  "| Bundled Dart (Bazel's Flutter 3.47.7 \`dart-sdk/version\`) | \`$dart_version\` |" \
  "| widget_test before / after the edit | exit $rc0 / $rc1 |" \
  "| \`greeting.flutter.koutline\` ($n1 files) before / after | \`$o1\` / \`$o2\` |" \
  "| \`greeting.koutline\` (rules_dart) before / after | \`$r1\` / \`$r2\` |" \
  "| \`greeting.flutter.kmod\` before / after (must change) | \`$k1\` / \`$k2\` |" \
  "| \"falling back to unstripped dill\": build output / worker logs | $fb_build / $fb_workers |"
ok=1
[[ "$dart_version" == 3.13.* ]] || ok=0
[[ $rc0 -eq 0 && $rc1 -eq 0 ]] || ok=0
[[ -n "$o1" && "$n1" -gt 0 && "$o1" == "$o2" && "$r1" == "$r2" ]] || ok=0
[[ "$k1" != "$k2" ]] || ok=0
[[ $fb_build -eq 0 && $fb_workers -eq 0 ]] || ok=0
finish T-0014-AC3 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
