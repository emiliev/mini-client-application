#!/bin/bash
# T-0014-AC3 (Verifier): .koutline byte identity after a body-only edit, with
# the disk cache off (--config=cold) so every kernel action really executes,
# plus the bundled Dart version and stripper-fallback diagnostics.
#   ac3-h-sdk.sh <output_base> <evidence dir>
set -uo pipefail
OB="$1"; E="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"
BW=(tool/bazelw "--output_base=$OB")
BIN="$OB/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/spike/greeting"
SRC=spike/greeting/lib/greeting.dart
listing() { (cd "$1" && find . -type f | sort | xargs shasum -a 256); }
snap() { for d in greeting.flutter.koutline greeting.koutline greeting.flutter.kmod greeting.kmod; do echo "== $d"; listing "$BIN/$d"; done; }

"${BW[@]}" test --config=cold //spike/hello:widget_test > "$E/ac3-before.log" 2>&1; echo "before: exit $?"
snap > "$E/ac3-digests-before.txt"
cp "$SRC" "$SRC.verifier.bak"
trap 'mv "$SRC.verifier.bak" "$SRC"' EXIT
# Body-only edit (different from the Engineer's): change a local and add a statement.
/usr/bin/sed -i '' "s/  return 'Hello, \$who';/  final n = who.length; assert(n > 0);\n  return 'Hello, \$who';/" "$SRC"
echo "--- edited source:"; cat "$SRC"
"${BW[@]}" test --config=cold //spike/hello:widget_test > "$E/ac3-after.log" 2>&1; echo "after: exit $?"
snap > "$E/ac3-digests-after.txt"
mv "$SRC.verifier.bak" "$SRC"; trap - EXIT
echo "--- reverted: $(git diff --stat -- "$SRC" | wc -l | tr -d ' ') changed files"
echo "--- digest diff (only .kmod lines expected):"
diff "$E/ac3-digests-before.txt" "$E/ac3-digests-after.txt"
echo "--- dart-sdk/version: $(cat "$OB/external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk/version")"
echo "--- fallback diagnostics in build logs: $(cat "$E"/ac3-*.log "$E"/ac*-cold.log | grep -a -c -E 'falling back to unstripped|unsupported kernel format version')"
echo "--- ... in worker logs: $(cat "$OB"/bazel-workers/*.log 2>/dev/null | grep -a -c -E 'falling back to unstripped|unsupported kernel format version')"
