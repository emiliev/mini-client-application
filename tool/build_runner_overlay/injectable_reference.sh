#!/bin/bash
# T-0028-AC1: build a package's injectable codegen with Bazel (fork patch 0002),
# produce the build_runner reference with stock injectable_generator 3.1.3 (with
# lean_builder) in a throwaway overlay, and compare byte for byte.
#
#   tool/build_runner_overlay/injectable_reference.sh spike/di_sample
#
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
# 1. Builds every DartCodegen / DartAggregateCodegen target of the package with
#    --remote_download_all (outputs land in bazel-bin even on cache hits).
# 2. Copies lib/ into .dart_tool/mc_overlay/<pkg>_injectable/ (git-ignored) with
#    injectable/pubspec.yaml and the first-party path deps (mc_di).
# 3. Resolves; fails if any hosted version differs from injectable/pubspec.lock.
# 4. Runs build_runner.
# 5. cmp's every *.config.dart with bazel-bin, and every shard build_runner
#    wrote (.dart_tool/build/generated) with Bazel's. Only the outputs the
#    targets declare (cquery --output=files) are compared, never stale files in
#    bazel-bin. A Bazel shard of `[]` with no build_runner counterpart is
#    expected (the generator returned null).
# Nothing is copied back into the source tree (R10 / D7).
# Exit: 0 all equal, 1 a difference / missing file / drift, 2 bad usage.
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
OVERLAY="$ROOT/tool/build_runner_overlay/injectable"
PKG_DIR="${1:?usage: injectable_reference.sh <package dir, e.g. spike/di_sample>}"
PKG_DIR="${PKG_DIR%/}"
[[ -f "$ROOT/$PKG_DIR/pubspec.yaml" ]] || { echo "no pubspec in $PKG_DIR" >&2; exit 2; }
PKG_NAME="$(awk '/^name:/{print $2; exit}' "$ROOT/$PKG_DIR/pubspec.yaml")"
SCRATCH="$ROOT/.dart_tool/mc_overlay/${PKG_NAME}_injectable"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bz() { "$ROOT/tool/bazelw" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }

echo "== 1. Bazel injectable codegen for //$PKG_DIR"
cd "$ROOT"
targets=$(bz query "kind('dart_codegen|dart_aggregate_codegen', //$PKG_DIR:*) except attr(tags, manual, //$PKG_DIR:*)" 2>/dev/null)
[[ -n "$targets" ]] || { echo "no codegen targets in //$PKG_DIR" >&2; exit 2; }
blog="$(mktemp)"
# shellcheck disable=SC2086
if ! bz build --remote_download_all $targets > "$blog" 2>&1; then
  tr '\r' '\n' < "$blog" | grep -a -E '^ERROR' || tail -20 "$blog"
  echo "FAIL: the Bazel build failed"; rm -f "$blog"; exit 1
fi
tr '\r' '\n' < "$blog" | grep -a -E '^INFO: Build completed' || true
rm -f "$blog"
BAZEL_BIN="$(bz info bazel-bin 2>/dev/null)"
# Exactly the files this build declares (never whatever else sits in bazel-bin).
outputs=$(bz cquery --output=files "$(printf '%s\n' $targets | paste -sd '+' - | sed 's/+/ + /g')" 2>/dev/null) || { echo "FAIL: cquery --output=files failed"; exit 1; }
[[ -n "$outputs" ]] || { echo "FAIL: the codegen targets declare no outputs"; exit 1; }

echo "== 2. Overlay scratch tree ${SCRATCH#"$ROOT"/}"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/_deps"
cp -R "$ROOT/$PKG_DIR/lib" "$SCRATCH/lib"
find "$SCRATCH/lib" \( -name '*.config.dart' -o -name '*.injectable.json' \) -delete
{
  sed "s/^name: .*/name: $PKG_NAME/" "$OVERLAY/pubspec.yaml" | awk '{ print } /^dependencies:$/ { print "  mc_di: any" }'
  printf 'dependency_overrides:\n  mc_di:\n    path: _deps/mc_di\n'
} > "$SCRATCH/pubspec.yaml"
mkdir -p "$SCRATCH/_deps/mc_di"
cp -R "$ROOT/utility/mc_di/lib" "$SCRATCH/_deps/mc_di/lib"
grep -v '^resolution: workspace' "$ROOT/utility/mc_di/pubspec.yaml" | sed '/^dev_dependencies:/,$d' > "$SCRATCH/_deps/mc_di/pubspec.yaml"
cp "$OVERLAY/pubspec.lock" "$SCRATCH/pubspec.lock"

echo "== 3. Resolve (hosted versions must equal the committed overlay lock)"
cd "$SCRATCH"
fvm dart pub get >/dev/null
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
for k in sorted(set(a) | set(b)):
    if k == "mc_di": continue
    if a.get(k) != b.get(k): print(f"{k}: lock {a.get(k)} -> resolved {b.get(k)}")
EOF
)
if [[ -n "$drift" ]]; then echo "DRIFT from tool/build_runner_overlay/injectable/pubspec.lock:"; echo "$drift"; exit 1; fi
echo "   analyzer $(awk '$0=="  analyzer:"{f=1} f&&/version:/{print $2; exit}' pubspec.lock), lean_builder $(awk '$0=="  lean_builder:"{f=1} f&&/version:/{print $2; exit}' pubspec.lock)"

echo "== 4. build_runner"
rlog="$(mktemp)"
if ! fvm dart run build_runner build --delete-conflicting-outputs > "$rlog" 2>&1; then
  tail -30 "$rlog"; echo "FAIL: build_runner failed"; rm -f "$rlog"; exit 1
fi
tail -2 "$rlog"; rm -f "$rlog"

echo "== 5. Compare with bazel-bin"
status=0
cmp_one() {  # <build_runner file> <bazel file> <label>
  if [[ ! -f "$2" ]]; then echo "MISSING in bazel-bin: $3"; status=1
  elif cmp -s "$1" "$2"; then echo "EQUAL   $3  sha256 $(shasum -a 256 "$2" | cut -c1-16)"
  else echo "DIFFER  $3"; diff -u "$1" "$2" || true; status=1; fi
}
# Declared outputs, as paths relative to the package (lib/...).
declared=$(printf '%s\n' "$outputs" | sed -n "s|^.*/bin/$PKG_DIR/||p" | sort -u)
configs=0
while IFS= read -r f; do
  rel="${f#./}"; configs=$((configs + 1))
  if ! grep -qxF "$rel" <<< "$declared"; then echo "MISSING in the Bazel targets: $PKG_DIR/$rel"; status=1; continue; fi
  cmp_one "$f" "$BAZEL_BIN/$PKG_DIR/$rel" "$PKG_DIR/$rel"
done < <(find ./lib -name '*.config.dart' -print | sort)
[[ $configs -gt 0 ]] || { echo "build_runner wrote no .config.dart"; status=1; }
GEN="$SCRATCH/.dart_tool/build/generated/$PKG_NAME"
shards=0
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  shards=$((shards + 1))
  bzshard="$BAZEL_BIN/$PKG_DIR/$rel"
  if [[ ! -f "$bzshard" ]]; then echo "MISSING in bazel-bin: $PKG_DIR/$rel"; status=1
  elif [[ -f "$GEN/$rel" ]]; then cmp_one "$GEN/$rel" "$bzshard" "$PKG_DIR/$rel (shard)"
  elif [[ "$(cat "$bzshard")" == "[]" ]]; then echo "EMPTY   $PKG_DIR/$rel (shard): Bazel [] / build_runner none (expected)"
  else echo "MISSING in build_runner: $PKG_DIR/$rel"; status=1; fi
done < <(grep -E '\.injectable\.json$' <<< "$declared")
[[ $shards -gt 0 ]] || { echo "the Bazel targets declare no shards"; status=1; }
# Every shard build_runner wrote must have a Bazel counterpart.
while IFS= read -r f; do
  rel="${f#"$GEN/"}"
  grep -qxF "$rel" <<< "$declared" || { echo "MISSING in the Bazel targets: $PKG_DIR/$rel (shard)"; status=1; }
done < <(find "$GEN/lib" -name '*.injectable.json' -print 2>/dev/null | sort)
exit $status
