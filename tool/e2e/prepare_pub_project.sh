#!/bin/bash
# tool/e2e/prepare_pub_project.sh: make an app runnable by `flutter drive`
# (pub mode) in a scratch copy of the repo, so tool/e2e_ios.sh can drive it.
#
# Why: the repo builds with Bazel (generated code is never committed, R10) and
# the apps have no Xcode project, but tool/e2e_ios.sh runs `flutter drive`.
# This script closes the gap without touching the working tree:
#   1. asks `cquery` which targets under the app library's deps produce a
#      generated Dart file (.g.dart, .freezed.dart, .config.dart, gen-l10n)
#      and builds exactly those, with --remote_download_outputs=all so each
#      file exists (a fresh output base with a warm disk cache is fine);
#   2. copies the tracked and new-but-not-ignored files of the repo to <out>
#      (git's own list: no .git, bazel-*, documents, build, and no stale
#      generated file left in the tree by an older build);
#   3. copies those listed generated files, and only those, from the Bazel
#      execroot to their source paths;
#   4. bundles tool/bazel/config/<env>.json as assets/app_config.json, as the
#      Bazel genrule does (R13);
#   5. runs `flutter create --platforms=ios` for the Xcode project (it never
#      overwrites an existing file) and `flutter pub get`.
#
#   tool/e2e/prepare_pub_project.sh --app app/mini_client --out /tmp/x [--env e2e]
#                                   [--bazel-target //app/mini_client:mini_client_lib]
# Environment: MC_OUTPUT_BASE selects the Bazel output base.
# Prints `GENERATED_FILES=<n>` and `E2E_PROJECT=<out>/<app>` on success; exits
# non-zero when anything needed for the claim (generated files, config asset,
# pub get) is missing.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="" OUT="" ENVNAME="e2e" TARGET=""
while [ $# -gt 0 ]; do
  case $1 in
    --app) APP=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --env) ENVNAME=$2; shift 2 ;;
    --bazel-target) TARGET=$2; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$APP" ] && [ -n "$OUT" ] || { echo "usage: --app <dir> --out <dir>" >&2; exit 2; }
[ -f "$REPO/$APP/pubspec.yaml" ] || { echo "no $APP/pubspec.yaml" >&2; exit 2; }
[ -f "$REPO/tool/bazel/config/$ENVNAME.json" ] || { echo "no config for env $ENVNAME" >&2; exit 2; }
[ ! -e "$OUT" ] || [ -z "$(ls -A "$OUT")" ] || { echo "$OUT is not empty" >&2; exit 2; }
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

NAME="$(basename "$APP")"
if [ -z "$TARGET" ]; then
  TARGET="//$APP:${NAME}_lib"
fi

bazel_args=()
if [ -n "${MC_OUTPUT_BASE:-}" ]; then
  bazel_args+=("--output_base=$MC_OUTPUT_BASE")
fi
bzl() { "$REPO/tool/bazelw" ${bazel_args[@]+"${bazel_args[@]}"} "$@"; }

cd "$REPO"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

echo "==> cquery: the generated Dart files under $TARGET"
# One line per output file of every dependency: "<label> <path>". Only files
# in bazel-out (generated) with a generated-Dart name are kept.
bzl cquery "deps($TARGET)" --output=starlark \
  --starlark:expr='"\n".join([str(target.label) + " " + f.path for f in target.files.to_list()])' \
  2>/dev/null >"$SCRATCH/all.txt"
# Tool configurations (-exec, built for the generators themselves) are not the
# app's own outputs, and a file is listed once.
awk '$2 ~ /^bazel-out\/[^\/]+\/bin\/(app|feature|utility)\// && $2 !~ /-exec\// &&
     ($2 ~ /\.g\.dart$/ || $2 ~ /\.freezed\.dart$/ || $2 ~ /\.config\.dart$/ ||
      $2 ~ /\/lib\/src\/l10n\/[^\/]*_l10n[^\/]*\.dart$/)' "$SCRATCH/all.txt" \
  | sort -u -k2,2 >"$SCRATCH/gen.txt"
count="$(wc -l <"$SCRATCH/gen.txt" | tr -d ' ')"
[ "$count" -gt 0 ] || { echo "no generated file under $TARGET: the app cannot compile" >&2; exit 1; }

echo "==> bazel build of the $(awk '{print $1}' "$SCRATCH/gen.txt" | sort -u | wc -l | tr -d ' ') targets that make them"
# shellcheck disable=SC2046
bzl build --remote_download_outputs=all "$TARGET" $(awk '{print $1}' "$SCRATCH/gen.txt" | sort -u) >/dev/null 2>"$SCRATCH/build.err" ||
  { cat "$SCRATCH/build.err" >&2; exit 1; }
EXEC="$(bzl info execution_root 2>/dev/null)"

echo "==> copying the repo's own files to $OUT"
# Git's list: tracked plus untracked-not-ignored, so no stale generated file
# (ignored by .gitignore) and no build output comes along.
git ls-files -z --cached --others --exclude-standard \
  | grep -zv '^documents/' \
  | (cd "$REPO" && rsync -a --from0 --files-from=- "$REPO/" "$OUT/")

echo "==> copying the $count generated files from the execroot"
while IFS=' ' read -r _label path; do
  src="$EXEC/$path"
  [ -f "$src" ] || { echo "listed output is missing: $src" >&2; exit 1; }
  rel="${path#bazel-out/*/bin/}"
  mkdir -p "$OUT/$(dirname "$rel")"
  cp -L "$src" "$OUT/$rel"
  chmod u+w "$OUT/$rel"
done <"$SCRATCH/gen.txt"
echo "GENERATED_FILES=$count"

echo "==> bundling the $ENVNAME config as assets/app_config.json"
mkdir -p "$OUT/$APP/assets"
cp "$REPO/tool/bazel/config/$ENVNAME.json" "$OUT/$APP/assets/app_config.json"
/usr/bin/python3 -I - "$OUT/$APP/pubspec.yaml" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
marker = "flutter:\n  uses-material-design: true\n"
if marker not in text:
    sys.exit("pubspec has no 'flutter: uses-material-design' block to extend")
text = text.replace(marker, marker + "  assets:\n    - assets/app_config.json\n", 1)
open(path, "w").write(text)
PY

cd "$OUT/$APP"
echo "==> flutter create --platforms=ios (adds the Xcode project; keeps existing files)"
fvm flutter create --platforms=ios --project-name "$NAME" --org com.emiliev --no-pub . >/dev/null
echo "==> flutter pub get"
cd "$OUT"
fvm flutter pub get >/dev/null

[ -f "$OUT/$APP/ios/Runner.xcodeproj/project.pbxproj" ] || { echo "no Xcode project" >&2; exit 1; }
[ -f "$OUT/$APP/assets/app_config.json" ] || { echo "no config asset" >&2; exit 1; }
echo "E2E_PROJECT=$OUT/$APP"
