#!/bin/bash
# T-0034-AC4: retrofit paths are relative (`'v1/characters'`), because
# `apiBaseUrl` ends with `/` (mc_config normalises it). Scans every
# hand-written Dart file of the repo for an HTTP-verb annotation whose path
# starts with `/`, and checks the configs' apiBaseUrl values end with `/`.
# FAILS on a hit, on a config without the slash, when it finds no retrofit
# annotation at all (an empty scan proves nothing), and when its negative
# control (a planted `@GET('/x')`) is not caught.
#   tool/checks/T-0034-AC4_relative_paths.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
VERB="@(GET|POST|PUT|PATCH|DELETE|HEAD)\( *"
scan() {  # scan <root>: leading-slash paths
  grep -r -n -E --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' \
    -e "${VERB}['\"]/" "$1" 2>/dev/null | grep -v '/bazel-' || true
}
count() { grep -r -E --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' -e "${VERB}['\"]" "$1" 2>/dev/null | grep -v -c '/bazel-' || true; }
roots=(${MC_T0034_ROOTS:-app feature spike utility})
hits=""; annotations=0
for r in "${roots[@]}"; do
  [[ -d "$r" ]] || continue
  hits+="$(scan "$r")"
  annotations=$((annotations + $(count "$r")))
done
bad_cfg=""
for f in tool/bazel/config/*.json; do
  url=$(/usr/bin/python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["apiBaseUrl"])' "$f")
  [[ "$url" == */ ]] || bad_cfg+="$f ($url) "
done

ctl="$(mktemp -d)"
trap 'rm -rf "$ctl"' EXIT
printf "@GET('/x')\nFuture<void> x();\n" > "$ctl/api.dart"
ctl_hits="$(scan "$ctl")"

report "# T-0034-AC4: relative retrofit paths" "" \
  "- retrofit verb annotations scanned: $annotations" "" \
  "| Check | Result |" "|---|---|" \
  "| leading-slash paths | ${hits:-none} |" \
  "| config apiBaseUrl without a trailing slash | ${bad_cfg:-none} |" \
  "| negative control (planted \`@GET('/x')\`) | $([[ -n "$ctl_hits" ]] && echo tripped || echo '**NOT tripped**') |"
ok=1
[[ -z "$hits" ]] || ok=0
[[ -z "$bad_cfg" ]] || ok=0
[[ "$annotations" -ge 1 ]] || ok=0
[[ -n "$ctl_hits" ]] || ok=0
finish T-0034-AC4-relative-paths $([[ $ok -eq 1 ]] && echo 0 || echo 1)
