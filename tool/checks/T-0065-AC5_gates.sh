#!/bin/bash
# T-0065-AC5: the gates for tool/mcgen, which Bazel does not build (F-0065:
# a standalone pub package with its own lockfile; an isolated Bazel hub
# would change MODULE.bazel.lock). Run this beside the usual merge gates.
#   1. `fvm dart pub get --offline` in tool/mcgen and tool/loc. This leaves
#      nested .dart_tool/package_config.json files on purpose: P-117.
#   2. the shared format gate passes with them there (P-117 fixed)
#   3. `fvm dart analyze` in tool/mcgen: no issues
#   4. `fvm dart test` in tool/mcgen: every test passes (T-0065-AC1..AC5)
#   5. pubspec.lock and MODULE.bazel.lock equal origin/main's
#   tool/checks/T-0065-AC5_gates.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
step() {  # step <label> <command...>
  local label="$1"; shift
  if "$@" > "$log" 2>&1; then
    report "- PASS: $label"
  else
    report "- **FAIL**: $label" '```' "$(tail -20 "$log")" '```'
    rc=1
  fi
}
report "# T-0065-AC5: tool/mcgen gates" "" "HEAD \`$(git rev-parse --short HEAD)\`" ""
step "pub get --offline in tool/mcgen" bash -c 'cd tool/mcgen && fvm dart pub get --offline'
step "pub get --offline in tool/loc" bash -c 'cd tool/loc && fvm dart pub get --offline'
step "format gate with nested .dart_tool in tool/mcgen and tool/loc (P-117)" tool/checks/lib/format_gate.sh
step "dart analyze tool/mcgen" bash -c 'cd tool/mcgen && fvm dart analyze --fatal-infos'
step "dart test tool/mcgen" bash -c 'cd tool/mcgen && fvm dart test --reporter=expanded'
if grep -aqE "All tests passed|Some tests failed" "$log"; then
  report "  - $(grep -aE 'All tests passed|Some tests failed' "$log" | tail -1)"
fi
step "pubspec.lock and MODULE.bazel.lock unchanged against origin/main" \
  git diff --quiet origin/main -- pubspec.lock MODULE.bazel.lock
finish T-0065-AC5 "$rc"
