#!/bin/bash
# T-0014 (AC6, AC7): build a package's Bazel codegen, produce build_runner
# reference outputs in a throwaway overlay, and compare them byte for byte.
#
#   tool/build_runner_overlay/spike_reference.sh spike/hello
#   MC_REF_SRCS_FROM=//feature/x/y:_stage tool/build_runner_overlay/spike_reference.sh feature/x/y
#
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
# MC_REF_SRCS_FROM names a library of the package whose `srcs` are the only
# files copied into the overlay (T-0032, for a Flutter feature: its
# Flutter-free generator inputs, R15). Unset: the whole lib/ is copied.
#
# 1. Builds every `dart_codegen` target of the package with
#    --remote_download_all, so the outputs are in bazel-bin even when they are
#    disk-cache hits (F-0009 gotcha 2), and lists the files those targets
#    declare (cquery --output=files).
# 2. Copies the package's lib/ (or the MC_REF_SRCS_FROM subset) into
#    .dart_tool/mc_overlay/<pkg>/ (git-ignored), with this overlay's pubspec,
#    the package's own hosted dependencies, and its first-party workspace deps
#    as path dependencies (copied beside it, `resolution: workspace` removed).
# 3. Resolves; fails if any hosted version differs from the committed overlay lock.
# 4. Runs build_runner; fails if `dart analyze` reports an unresolved import.
# 5. cmp's each build_runner *.g.dart / *.freezed.dart against bazel-bin/<pkg>/.
#    Only declared outputs count (P-054): a build_runner file the targets don't
#    declare, or a declared .g.dart / .freezed.dart build_runner didn't write,
#    fails; a stale file in bazel-bin is never compared.
# Nothing is copied back into the source tree (R10 / D7).
# Exit: 0 all equal, 1 a failed Bazel build / difference / missing file / drift /
# unresolved import, 2 bad usage.
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
OVERLAY="$ROOT/tool/build_runner_overlay"
PKG_DIR="${1:?usage: spike_reference.sh <package dir, e.g. spike/hello>}"
PKG_DIR="${PKG_DIR%/}"
[[ -f "$ROOT/$PKG_DIR/pubspec.yaml" ]] || { echo "no pubspec in $PKG_DIR" >&2; exit 2; }
PKG_NAME="$(awk '/^name:/{print $2; exit}' "$ROOT/$PKG_DIR/pubspec.yaml")"
SCRATCH="$ROOT/.dart_tool/mc_overlay/$PKG_NAME"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bz() { "$ROOT/tool/bazelw" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }

echo "== 1. Bazel codegen for //$PKG_DIR"
cd "$ROOT"
targets=$(bz query "kind(\"dart_codegen\", //$PKG_DIR:*)" 2>/dev/null)
[[ -n "$targets" ]] || { echo "no dart_codegen targets in //$PKG_DIR" >&2; exit 2; }
mkdir -p "$ROOT/.dart_tool"
# shellcheck disable=SC2086
bz build --remote_download_all $targets > "$ROOT/.dart_tool/mc_overlay_bazel.log" 2>&1 && build_rc=0 || build_rc=$?
tr '\r' '\n' < "$ROOT/.dart_tool/mc_overlay_bazel.log" | grep -a -E '^(ERROR|INFO: Build completed)' || true
# A failed build would leave stale or missing outputs in bazel-bin (P-024).
if [[ $build_rc -ne 0 ]]; then echo "BAZEL BUILD FAILED (exit $build_rc): not comparing stale outputs"; exit 1; fi
BAZEL_BIN="$(bz info bazel-bin 2>/dev/null)"
# Exactly the files these targets declare, relative to the package (lib/...).
outputs=$(bz cquery --output=files "$(printf '%s\n' $targets | paste -sd '+' - | sed 's/+/ + /g')" 2>/dev/null) \
  || { echo "FAIL: cquery --output=files failed"; exit 1; }
declared=$(printf '%s\n' "$outputs" | sed -n "s|^.*/bin/$PKG_DIR/||p" | grep -E '\.(g|freezed)\.dart$' | sort -u || true)
[[ -n "$declared" ]] || { echo "FAIL: the codegen targets declare no .g.dart / .freezed.dart"; exit 1; }

echo "== 2. Overlay scratch tree ${SCRATCH#"$ROOT"/}"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/_deps"
if [[ -n "${MC_REF_SRCS_FROM:-}" ]]; then
  srcs=$(bz cquery "labels(srcs, $MC_REF_SRCS_FROM)" --output=files 2>/dev/null | grep -E "^$PKG_DIR/lib/.*\.dart$" | sort -u) \
    || { echo "FAIL: no source files in $MC_REF_SRCS_FROM"; exit 1; }
  [[ -n "$srcs" ]] || { echo "FAIL: no source files in $MC_REF_SRCS_FROM"; exit 1; }
  echo "   $(wc -l <<< "$srcs" | tr -d ' ') files from $MC_REF_SRCS_FROM"
  while IFS= read -r f; do
    mkdir -p "$SCRATCH/$(dirname "${f#"$PKG_DIR"/}")"
    cp "$ROOT/$f" "$SCRATCH/${f#"$PKG_DIR"/}"
  done <<< "$srcs"
else
  cp -R "$ROOT/$PKG_DIR/lib" "$SCRATCH/lib"
fi
find "$SCRATCH/lib" \( -name '*.g.dart' -o -name '*.freezed.dart' \) -delete
# First-party deps (workspace members, transitively, as path deps) and the
# package's own hosted deps (tool/build_runner_overlay/overlay_deps.py).
deps_info=$(/usr/bin/python3 -I "$OVERLAY/overlay_deps.py" "$ROOT" "$PKG_DIR")
first_party=$(sed -n 's/^first	//p' <<< "$deps_info")
hosted=$(sed -n 's/^hosted	//p' <<< "$deps_info")
sed "s/^name: .*/name: $PKG_NAME/" "$OVERLAY/pubspec.yaml" > "$SCRATCH/pubspec.yaml"
add_dep() { /usr/bin/python3 -I "$OVERLAY/add_dep.py" "$SCRATCH/pubspec.yaml" "$1"; }
while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  add_dep "$dep"
done <<< "$hosted"
if [[ -n "$first_party" ]]; then
  echo "dependency_overrides:" >> "$SCRATCH/pubspec.yaml"
  while IFS=$'\t' read -r dep dir; do
    echo "   first-party path dep: $dep ($dir)"
    mkdir -p "$SCRATCH/_deps/$dep"
    cp -R "$ROOT/$dir/lib" "$SCRATCH/_deps/$dep/lib"
    grep -v '^resolution: workspace' "$ROOT/$dir/pubspec.yaml" > "$SCRATCH/_deps/$dep/pubspec.yaml"
    # As a regular dependency too, so the import is declared, not only overridden.
    add_dep "$dep"
    printf '  %s:\n    path: _deps/%s\n' "$dep" "$dep" >> "$SCRATCH/pubspec.yaml"
  done <<< "$first_party"
fi
cp "$OVERLAY/pubspec.lock" "$SCRATCH/pubspec.lock"

echo "== 3. Resolve (hosted versions must equal the committed overlay lock)"
cd "$SCRATCH"
fvm flutter pub get >/dev/null
drift=$(/usr/bin/python3 -I - "$OVERLAY/pubspec.lock" "$SCRATCH/pubspec.lock" <<'EOF'
import re, sys
def load(p):
    d, cur = {}, None
    for l in open(p):
        m = re.match(r"^  ([a-z0-9_]+):$", l)
        if m: cur = m.group(1)
        m = re.match(r'^    version: "(.*)"', l)
        if m and cur: d[cur] = m.group(1)
    return d
a, b = load(sys.argv[1]), load(sys.argv[2])
for k in sorted(set(a) & set(b)):
    if a[k] != b[k]: print(f"{k}: lock {a[k]} -> resolved {b[k]}")
EOF
)
if [[ -n "$drift" ]]; then echo "DRIFT from tool/build_runner_overlay/pubspec.lock:"; echo "$drift"; exit 1; fi

echo "== 4. build_runner"
fvm dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -2
unresolved=$(fvm dart analyze lib 2>&1 | grep -E 'uri_does_not_exist|uri_has_not_been_generated|depend_on_referenced_packages' || true)
if [[ -n "$unresolved" ]]; then echo "UNRESOLVED imports in the overlay:"; echo "$unresolved"; exit 1; fi
echo "   dart analyze: no unresolved imports"

echo "== 5. Compare with bazel-bin (declared outputs only)"
status=0
compared=""
while IFS= read -r f; do
  rel="${f#./}"
  compared+="$rel"$'\n'
  bz_file="$BAZEL_BIN/$PKG_DIR/$rel"
  if ! grep -qxF "$rel" <<< "$declared"; then
    echo "MISSING in the Bazel targets: $PKG_DIR/$rel"
    status=1
  elif [[ ! -f "$bz_file" ]]; then
    echo "MISSING in bazel-bin: $PKG_DIR/$rel"
    status=1
  elif cmp -s "$f" "$bz_file"; then
    echo "EQUAL   $PKG_DIR/$rel  sha256 $(shasum -a 256 "$bz_file" | cut -c1-16)"
  else
    echo "DIFFER  $PKG_DIR/$rel"
    diff -u "$f" "$bz_file" || true
    status=1
  fi
done < <(find ./lib \( -name '*.g.dart' -o -name '*.freezed.dart' \) -print | sort)
# Every declared output needs a build_runner counterpart.
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  grep -qxF "$rel" <<< "$compared" || { echo "MISSING in build_runner: $PKG_DIR/$rel"; status=1; }
done <<< "$declared"
exit $status
