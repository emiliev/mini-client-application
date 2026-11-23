#!/bin/bash
# T-0014 (AC6, AC7): build a package's Bazel codegen, produce build_runner
# reference outputs in a throwaway overlay, and compare them byte for byte.
#
#   tool/build_runner_overlay/spike_reference.sh spike/hello
#
# 1. Builds every `dart_codegen` target of the package with
#    --remote_download_all, so the outputs are in bazel-bin even when they are
#    disk-cache hits (F-0009 gotcha 2).
# 2. Copies the package's lib/ into .dart_tool/mc_overlay/<pkg>/ (git-ignored),
#    with this overlay's pubspec plus the package's first-party workspace deps
#    as path dependencies (copied beside it, `resolution: workspace` removed).
# 3. Resolves; fails if any hosted version differs from the committed overlay lock.
# 4. Runs build_runner; fails if `dart analyze` reports an unresolved import.
# 5. cmp's each *.g.dart / *.freezed.dart against bazel-bin/<pkg>/.
# Nothing is copied back into the source tree (R10 / D7).
# Exit: 0 all equal, 1 a difference / missing file / drift / unresolved import, 2 bad usage.
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
OVERLAY="$ROOT/tool/build_runner_overlay"
PKG_DIR="${1:?usage: spike_reference.sh <package dir, e.g. spike/hello>}"
PKG_DIR="${PKG_DIR%/}"
[[ -f "$ROOT/$PKG_DIR/pubspec.yaml" ]] || { echo "no pubspec in $PKG_DIR" >&2; exit 2; }
PKG_NAME="$(awk '/^name:/{print $2; exit}' "$ROOT/$PKG_DIR/pubspec.yaml")"
SCRATCH="$ROOT/.dart_tool/mc_overlay/$PKG_NAME"
BAZELW="$ROOT/tool/bazelw"

echo "== 1. Bazel codegen for //$PKG_DIR"
cd "$ROOT"
targets=$("$BAZELW" query "kind(\"dart_codegen\", //$PKG_DIR:*)" 2>/dev/null)
[[ -n "$targets" ]] || { echo "no dart_codegen targets in //$PKG_DIR" >&2; exit 2; }
# shellcheck disable=SC2086
"$BAZELW" build --remote_download_all $targets 2>&1 | tr '\r' '\n' | grep -a -E '^(ERROR|INFO: Build completed)' || true
BAZEL_BIN="$("$BAZELW" info bazel-bin 2>/dev/null)"

echo "== 2. Overlay scratch tree ${SCRATCH#"$ROOT"/}"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/_deps"
cp -R "$ROOT/$PKG_DIR/lib" "$SCRATCH/lib"
find "$SCRATCH/lib" \( -name '*.g.dart' -o -name '*.freezed.dart' \) -delete
# First-party deps: workspace members named in the package's dependencies,
# followed transitively. Prints "name<TAB>dir" lines.
first_party=$(/usr/bin/python3 -I - "$ROOT" "$PKG_DIR" <<'EOF'
import os, re, sys
root, pkg = sys.argv[1], sys.argv[2]
def read(p): return open(os.path.join(root, p, "pubspec.yaml")).read()
def name(text): return re.search(r"^name:\s*(\S+)", text, re.M).group(1)
members = re.search(r"^workspace:\n((?:\s+-\s*.+\n?)+)", open(os.path.join(root, "pubspec.yaml")).read(), re.M)
dirs = [l.split("-", 1)[1].strip() for l in members.group(1).splitlines() if l.strip()] if members else []
by_name = {name(read(d)): d for d in dirs}
def deps(text):
    m = re.search(r"^dependencies:\n((?:[ \t]+.*\n?)*)", text, re.M)
    return re.findall(r"^  ([a-z0-9_]+):", m.group(1), re.M) if m else []
seen, todo = {}, [pkg]
while todo:
    for d in deps(read(todo.pop())):
        if d in by_name and d not in seen:
            seen[d] = by_name[d]; todo.append(by_name[d])
for n, d in sorted(seen.items()): print(f"{n}\t{d}")
EOF
)
sed "s/^name: .*/name: $PKG_NAME/" "$OVERLAY/pubspec.yaml" > "$SCRATCH/pubspec.yaml"
if [[ -n "$first_party" ]]; then
  echo "dependency_overrides:" >> "$SCRATCH/pubspec.yaml"
  while IFS=$'\t' read -r dep dir; do
    echo "   first-party path dep: $dep ($dir)"
    mkdir -p "$SCRATCH/_deps/$dep"
    cp -R "$ROOT/$dir/lib" "$SCRATCH/_deps/$dep/lib"
    grep -v '^resolution: workspace' "$ROOT/$dir/pubspec.yaml" > "$SCRATCH/_deps/$dep/pubspec.yaml"
    # As a regular dependency too, so the import is declared, not only overridden.
    /usr/bin/python3 -I - "$SCRATCH/pubspec.yaml" "$dep" <<'EOF'
import sys
p, dep = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace("\ndependencies:\n", f"\ndependencies:\n  {dep}: any\n", 1)
open(p, "w").write(s)
EOF
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

echo "== 5. Compare with bazel-bin"
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
done < <(find ./lib \( -name '*.g.dart' -o -name '*.freezed.dart' \) -print | sort)
exit $status
