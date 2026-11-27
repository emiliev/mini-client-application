#!/bin/bash
# T-0063-AC7: the `flutter_gen_l10n` rule's output for settings_appearance equals
# `fvm flutter gen-l10n`'s for the same inputs in a throwaway copy (the
# T-0025-AC4 check, for a feature package). The CLI runs `dart format` over
# its output and the rule does not (F-0023), so the Bazel output is compared
# raw (informational) and after `dart format` (the verdict). The copy gets a
# pubspec with only the SDK dependencies gen-l10n needs: the package's own
# first-party `any` dependencies do not resolve outside the pub workspace,
# and gen-l10n reads only l10n.yaml and the ARBs.
#   tool/checks/T-0063-AC7_gen_l10n_parity.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG=feature/settings/settings_appearance
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

bzw build //$PKG:_l10n >/dev/null 2>&1 || finish T-0063-AC7-gen-l10n 1
bin="$(bzw info bazel-bin 2>/dev/null)/$PKG/lib/src/l10n"

# Throwaway copy: out of the pub workspace (drop `resolution: workspace`), with
# the repo's pinned Flutter (.fvmrc) and no generated files left from `pub get`.
cp -R "$REPO/$PKG" "$work/pkg"
cp "$REPO/.fvmrc" "$work/.fvmrc"
cat > "$work/pkg/pubspec.yaml" <<'YAML'
name: settings_appearance
publish_to: none
environment:
  sdk: ^3.13.0
  flutter: ^3.47.7
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
flutter:
  generate: true
YAML
rm -f "$work/pkg/lib/src/l10n/"*_l10n*.dart
pinned="$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' "$REPO/.fvmrc")"
(cd "$work/pkg" && fvm flutter --version 2>/dev/null | grep -q "Flutter $pinned") || {
  report "pinned Flutter $pinned is not what fvm resolves in the copy"; finish T-0063-AC7-gen-l10n 1; }
(cd "$work/pkg" && fvm flutter gen-l10n >"$work/cli.log" 2>&1 </dev/null) || {
  report "fvm flutter gen-l10n failed:" '```' "$(cat "$work/cli.log")" '```'; finish T-0063-AC7-gen-l10n 1; }

mkdir "$work/bazel" "$work/bazel_fmt"
cp "$bin"/*.dart "$work/bazel/" && chmod u+w "$work/bazel"/*
cp "$work/bazel"/*.dart "$work/bazel_fmt/"
fvm dart format --language-version=3.13 "$work/bazel_fmt" >/dev/null 2>&1

ok=1
report "# T-0063-AC7: settings_appearance flutter_gen_l10n vs fvm flutter gen-l10n" "" "| file | raw | after dart format |" "|---|---|---|"
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
finish T-0063-AC7-gen-l10n $([[ $ok -eq 1 ]] && echo 0 || echo 1)
