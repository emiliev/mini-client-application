#!/bin/bash
# T-0025-AC4: the `flutter_gen_l10n` rule's output for mc_l10n_core equals
# `fvm flutter gen-l10n`'s for the same inputs in a throwaway copy. The CLI runs
# `dart format` over its output and the rule does not (F-0022), so the Bazel
# output is compared raw (informational) and after `dart format` (the verdict).
#   tool/checks/T-0025-AC4_gen_l10n_parity.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG=utility/mc_l10n_core
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

"$BAZELW" build //$PKG:_l10n >/dev/null 2>&1 || finish T-0025-AC4 1
bin="$("$BAZELW" info bazel-bin 2>/dev/null)/$PKG/lib/src/l10n"

# Throwaway copy: out of the pub workspace, with the `flutter: generate` flag the CLI insists on.
cp -R "$REPO/$PKG" "$work/pkg"
sed -i '' '/^resolution: workspace/d' "$work/pkg/pubspec.yaml"
printf '\nflutter:\n  generate: true\n' >> "$work/pkg/pubspec.yaml"
(cd "$work/pkg" && fvm flutter gen-l10n >"$work/cli.log" 2>&1)

mkdir "$work/bazel" "$work/bazel_fmt"
cp "$bin"/*.dart "$work/bazel/" && chmod u+w "$work/bazel"/*
cp "$work/bazel"/*.dart "$work/bazel_fmt/"
fvm dart format --language-version=3.13 "$work/bazel_fmt" >/dev/null 2>&1

ok=1
report "# T-0025-AC4: flutter_gen_l10n vs fvm flutter gen-l10n" "" "| file | raw | after dart format |" "|---|---|---|"
for f in "$work/pkg/lib/src/l10n/"*.dart; do
  n="$(basename "$f")"
  raw=differs; fmt=differs
  cmp -s "$f" "$work/bazel/$n" && raw=identical
  cmp -s "$f" "$work/bazel_fmt/$n" && fmt=identical
  [[ "$fmt" == identical ]] || ok=0
  report "| $n | $raw | $fmt |"
done
n_cli=$(ls "$work/pkg/lib/src/l10n/"*.dart | wc -l | tr -d ' ')
n_bzl=$(ls "$work/bazel"/*.dart | wc -l | tr -d ' ')
[[ "$n_cli" == "$n_bzl" ]] || { ok=0; report "" "file count differs: cli $n_cli, bazel $n_bzl"; }
finish T-0025-AC4 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
