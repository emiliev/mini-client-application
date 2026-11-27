#!/bin/bash
# tool/checks/lib/format_gate.sh: the one shared `dart format` gate (T-0062,
# P-101 and P-111). Future gate scripts call this instead of their own
# `dart format` line; the old per-task scripts are left as they were.
#
#   tool/checks/lib/format_gate.sh          # check only: exit 0 when nothing would change
#   tool/checks/lib/format_gate.sh --fix    # rewrite the gated directories in place
#   source tool/checks/lib/format_gate.sh   # defines mc_format_gate [--fix]
#
# What it does:
#   0. MC_DART (T-0068, CI): a command line for the Dart to use instead of `fvm dart`, e.g.
#      MC_DART=dart on a runner whose PATH has Flutter 3.47.7 (.fvmrc). With it set, step 1 runs
#      `$MC_PUB_GET` (default `$MC_DART pub get`; CI sets `flutter pub get`) online. Default stays `fvm dart`.
#   1. `fvm dart pub get --offline` at the repo root when
#      .dart_tool/package_config.json is missing. The formatter resolves
#      `package:mc_analysis/analysis_options.yaml` through it; without it a
#      fresh worktree formats with the wrong style (140 false changes) and
#      the gate fails (P-101).
#   2. formats exactly the repo's own Dart sources: app, feature, utility,
#      spike and tool (tool/loc included). `third_party/` (vendored, must
#      stay as patched) and `documents/` are never passed to the formatter
#      (P-111). Evidence probes go in documents/ as `.dart.txt`, so nothing
#      there is Dart.
# It is the only tool that may run `dart format` over the repo; never run
# `dart format .` by hand.

MC_FORMAT_DIRS=(app feature utility spike tool)
read -r -a MC_DART_CMD <<< "${MC_DART:-fvm dart}"
MC_FORMAT_GATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mc_format_gate() {
  local fix=0 root dirs=() d
  [ "${1:-}" != "--fix" ] || fix=1
  root="$(git -C "$MC_FORMAT_GATE_DIR" rev-parse --show-toplevel)" || return 2
  if [ ! -f "$root/.dart_tool/package_config.json" ]; then
    local pub=("${MC_DART_CMD[@]}" pub get --offline)
    if [ -n "${MC_DART:-}" ]; then
      # CI: MC_PUB_GET (e.g. `flutter pub get`) initialises a fresh Flutter SDK clone first
      # (downloads bin/cache/pkg/sky_engine); plain `dart pub get` fails on it.
      read -r -a pub <<< "${MC_PUB_GET:-$MC_DART pub get}"
    fi
    echo "format gate: no .dart_tool/package_config.json; running '${pub[*]}'" >&2
    (cd "$root" && "${pub[@]}" >/dev/null) || {
      echo "format gate: '${pub[*]}' failed" >&2
      return 2
    }
  fi
  for d in "${MC_FORMAT_DIRS[@]}"; do
    [ -d "$root/$d" ] && dirs+=("$d")
  done
  if [ "$fix" = 1 ]; then
    (cd "$root" && "${MC_DART_CMD[@]}" format "${dirs[@]}")
  else
    (cd "$root" && "${MC_DART_CMD[@]}" format --output=none --set-exit-if-changed "${dirs[@]}")
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  mc_format_gate "$@"
fi
