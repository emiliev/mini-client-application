#!/bin/bash
# T-0014 AC3 (H-SDK): bundled Dart version, .koutline byte-identical after a
# body-only edit, and no stripper-fallback diagnostic.
set -uo pipefail
REPO=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a5c44fd531dc49825
cd "$REPO"
E=$REPO/documents/evidence/T-0014/engineer
OUT=$E/ac3-h-sdk.md
OB=$(tool/bazelw info output_base 2>/dev/null)
SDK=$OB/external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk
KO=bazel-out/darwin_arm64-fastbuild/bin/spike/greeting/greeting.flutter.koutline
KO2=bazel-out/darwin_arm64-fastbuild/bin/spike/greeting/greeting.koutline
KM=bazel-out/darwin_arm64-fastbuild/bin/spike/greeting/greeting.flutter.kmod
SRC=spike/greeting/lib/greeting.dart
digest() { (cd "$1" && find -L . -type f | sort | xargs shasum -a 256) | shasum -a 256 | cut -c1-16; }
listing() { (cd "$1" && find -L . -type f | sort | xargs shasum -a 256); }

tool/bazelw test --remote_download_all //spike/hello:widget_test >/dev/null 2>&1
before_o=$(digest "$KO"); before_o2=$(digest "$KO2"); before_k=$(digest "$KM"); listing "$KO" > /tmp/ko_before.$$
cp "$SRC" "$SRC.bak"
trap 'mv "$SRC.bak" "$SRC"' EXIT
# Body-only edit: the constant inside the function body changes; the signature does not.
sed -i '' "s/const who = 'mini-client';/const who = 'mini-client';  \/\/ body edit\n  assert(who.isNotEmpty);/" "$SRC"
set +e
tool/bazelw test --remote_download_all //spike/hello:widget_test > "$E/ac3-after-body-edit.log" 2>&1
rc=$?
after_o=$(digest "$KO"); after_o2=$(digest "$KO2"); after_k=$(digest "$KM"); listing "$KO" > /tmp/ko_after.$$
mv "$SRC.bak" "$SRC"; trap - EXIT
tool/bazelw build //spike/hello:hello_lib >/dev/null 2>&1

fallback_build=$(grep -a -c 'falling back to unstripped dill' "$E"/*.log 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
fallback_workers=$(grep -a -h -c 'falling back to unstripped dill' "$OB"/bazel-workers/*.log 2>/dev/null | awk '{s+=$1} END{print s+0}')
{
  echo "# T-0014-AC3: H-SDK evidence"
  echo
  echo "| Check | Result |"
  echo "|---|---|"
  echo "| Bundled Dart (\`dart-sdk/version\` of the Bazel-fetched Flutter 3.47.7) | \`$(cat "$SDK/version")\` |"
  echo "| \`dart --version\` (that SDK) | \`$("$SDK/bin/dart" --version 2>&1)\` |"
  echo "| Kernel format the stripper accepts | 138 (Dart 3.13.x); 3.13.5 is in range |"
  echo "| Edit | \`$SRC\`: body-only (added a statement inside \`greeting()\`), then reverted |"
  echo "| \`greeting.flutter.koutline\` (rules_flutter module) digest before / after | \`$before_o\` / \`$after_o\` |"
  echo "| \`greeting.koutline\` (rules_dart DartKernel) digest before / after | \`$before_o2\` / \`$after_o2\` |"
  echo "| \`greeting.flutter.kmod\` digest before / after (should change) | \`$before_k\` / \`$after_k\` |"
  echo "| Test after the edit | exit $rc; $(tr '\r' '\n' < "$E/ac3-after-body-edit.log" | grep -a -E 'processes:' | tail -1) |"
  echo "| \"falling back to unstripped dill\" in build logs | $fallback_build |"
  echo "| ... in \`bazel-workers/*.log\` | ${fallback_workers:-0} |"
  echo
  echo "Per-file koutline listing diff (empty = byte-identical):"
  echo '```'
  diff /tmp/ko_before.$$ /tmp/ko_after.$$ || true
  echo '```'
} > "$OUT"
rm -f /tmp/ko_before.$$ /tmp/ko_after.$$
cat "$OUT"
