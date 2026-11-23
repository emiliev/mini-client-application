#!/bin/bash
# T-0014 (AC6, AC7): produce build_runner reference outputs for a package and
# compare them with what Bazel's stock shims generated.
#
#   tool/build_runner_overlay/spike_reference.sh spike/hello
#
# It copies the package's lib/ into .dart_tool/mc_overlay/<pkg>/ (git-ignored),
# with this overlay's pubspec and lock, runs build_runner there, and diffs each
# *.g.dart / *.freezed.dart against bazel-bin/<pkg>/. Nothing is copied back
# into the source tree (R10 / D7). Run the Bazel build first.
# Exit: 0 all equal, 1 a difference or a missing file, 2 bad usage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERLAY="$ROOT/tool/build_runner_overlay"
PKG_DIR="${1:?usage: spike_reference.sh <package dir, e.g. spike/hello>}"
[[ -f "$ROOT/$PKG_DIR/pubspec.yaml" ]] || { echo "no pubspec in $PKG_DIR" >&2; exit 2; }
PKG_NAME="$(awk '/^name:/{print $2; exit}' "$ROOT/$PKG_DIR/pubspec.yaml")"
SCRATCH="$ROOT/.dart_tool/mc_overlay/$PKG_NAME"

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
cp -R "$ROOT/$PKG_DIR/lib" "$SCRATCH/lib"
find "$SCRATCH/lib" \( -name '*.g.dart' -o -name '*.freezed.dart' \) -delete
# Same dependency set as the overlay; only the package name changes, so the
# committed overlay lock applies unchanged.
sed "s/^name: .*/name: $PKG_NAME/" "$OVERLAY/pubspec.yaml" > "$SCRATCH/pubspec.yaml"
cp "$OVERLAY/pubspec.lock" "$SCRATCH/pubspec.lock"

cd "$SCRATCH"
fvm flutter pub get --enforce-lockfile >/dev/null
fvm dart run build_runner build --delete-conflicting-outputs

BAZEL_BIN="$(cd "$ROOT" && "$ROOT/tool/bazelw" info bazel-bin 2>/dev/null)"
status=0
while IFS= read -r f; do
  rel="${f#./}"
  bz="$BAZEL_BIN/$PKG_DIR/$rel"
  if [[ ! -f "$bz" ]]; then
    echo "MISSING in bazel-bin: $PKG_DIR/$rel"
    status=1
  elif cmp -s "$f" "$bz"; then
    echo "EQUAL   $PKG_DIR/$rel"
  else
    echo "DIFFER  $PKG_DIR/$rel"
    diff -u "$f" "$bz" || true
    status=1
  fi
done < <(find . -path ./.dart_tool -prune -o \( -name '*.g.dart' -o -name '*.freezed.dart' \) -print | sort)
exit $status
