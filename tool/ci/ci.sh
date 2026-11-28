#!/bin/bash
# tool/ci/ci.sh: the delivery gates, in order, stopping at the first failure (T-0068).
# CI (.github/workflows/ci.yml) and humans run this same script; it mirrors the TL merge gate
# of ADR-0015 minus the flake check and the review-only items.
#
#   tool/ci/ci.sh                  # all gates
#   tool/ci/ci.sh --list           # print the gate names and exit
#   tool/ci/ci.sh --only 5         # run just gate 5 (by number)
#
# Environment (all optional; the defaults work on the dev Mac):
#   MC_BAZEL_STARTUP   extra Bazel startup options, e.g. "--output_base=/tmp/mc-ob-x"
#   MC_CI_CACHE_DIR    put the Bazel disk and repository caches under this directory instead of
#                      ~/.cache/mc-bazel (a cold, measurable cache; CI uses the default)
#   MC_CI_LOG_DIR      where the per-gate logs and summary.md go (default: a fresh temp dir)
#   MC_BAZELISK        bazelisk binary; default Homebrew's, else `bazelisk` on PATH (tool/bazelw)
#   MC_DART            Dart command for the format gate; default `fvm dart` (tool/checks/lib/format_gate.sh).
#                      On a clean machine set it to `dart` with Flutter 3.47.7 on PATH.
# Without MC_DART and without `fvm`, `dart` on PATH is used (CI has no FVM).
set -uo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 2
cd "$ROOT" || exit 2
BZW="$ROOT/tool/bazelw"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
CACHE_FLAGS=()
if [[ -n "${MC_CI_CACHE_DIR:-}" ]]; then
  CACHE_FLAGS=("--disk_cache=$MC_CI_CACHE_DIR/disk" "--repository_cache=$MC_CI_CACHE_DIR/repo")
fi
LOG_DIR="${MC_CI_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
if [[ -z "${MC_DART:-}" ]] && ! command -v fvm >/dev/null 2>&1; then export MC_DART=dart; fi

bz() { "$BZW" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }  # bz <command> <args>: startup options first
# bzc <command> <args>: the command, then the cache flags, then the rest.
bzc() { local c="$1"; shift; bz "$c" ${CACHE_FLAGS[@]+"${CACHE_FLAGS[@]}"} "$@"; }

g_rules_fork()  { "$ROOT/tool/rules_fork.sh" check; }
g_test()        { bzc test --config=ci //...; }
g_lint()        { bzc build --config=ci --config=lint //...; }
g_arch()        { bzc run --config=ci //tool/mc_arch_check:bin; }
g_format()      { "$ROOT/tool/checks/lib/format_gate.sh"; }
# tool/mcgen is a standalone pub package Bazel does not build (F-0065): pub get, analyze, test.
# MC_DART set (CI): online `pub get` (empty pub cache); else `fvm dart` with --offline, as the format gate.
g_mcgen() {
  local dart pub=() d
  read -r -a dart <<< "${MC_DART:-fvm dart}"
  pub=(pub get --offline); [[ -z "${MC_DART:-}" ]] || pub=(pub get)
  for d in tool/loc tool/mcgen; do
    (cd "$ROOT/$d" && "${dart[@]}" "${pub[@]}") || return 1
  done
  cd "$ROOT/tool/mcgen" || return 1
  "${dart[@]}" analyze --fatal-infos || return 1
  "${dart[@]}" test --reporter=expanded || return 1
  # T-0074: the wire-owned files and the BUILD files buildgen covers equal a
  # fresh regeneration (plan 02 section 2.8: never edited by hand).
  "${dart[@]}" run bin/mcgen.dart wire --check --root "$ROOT" || return 1
  "${dart[@]}" run bin/mcgen.dart buildgen --check --root "$ROOT"
}
g_l10n()        { bzc run --config=ci //tool/l10n_check:bin -- "$ROOT"; }
g_provenance()  { "$ROOT/tool/checks/T-0035-AC4_provenance.sh"; }
g_overlays()    { "$ROOT/tool/checks/T-0058-AC4_no_direct_overlays.sh"; }
g_sim()         { bzc build --config=ci --config=sim //app/mini_client:mini_client_ios; }
g_apptests() {
  local q
  q="$(bz query 'attr(tags, "\bapp\b", tests(//...))' 2>/dev/null)" || return 1
  if [[ -z "$q" ]]; then echo "no app-tagged tests; nothing to run"; return 0; fi
  bzc test --config=ci --config=app //...
}

NAMES=("rules_fork.sh check" "bazel test //..." "bazel build lint //..." "mc_arch_check" "format gate" "mcgen analyze, test, wire and buildgen --check" \
       "l10n_check" "flow_builder provenance" "no direct overlays" "sim app build" "app-tagged tests")
FUNCS=(g_rules_fork g_test g_lint g_arch g_format g_mcgen g_l10n g_provenance g_overlays g_sim g_apptests)

only=""
case "${1:-}" in
  --list) for i in "${!NAMES[@]}"; do echo "$((i+1)). ${NAMES[$i]}"; done; exit 0 ;;
  --only) only="${2:?--only needs a gate number}" ;;
  "") ;;
  *) echo "usage: tool/ci/ci.sh [--list | --only N]" >&2; exit 2 ;;
esac

SUMMARY="$LOG_DIR/summary.md"
printf '| # | Gate | Result | Seconds |\n|---|---|---|---|\n' > "$SUMMARY"
echo "ci.sh: repo $ROOT, logs $LOG_DIR"
total_start=$SECONDS
rc=0
for i in "${!NAMES[@]}"; do
  n=$((i+1))
  [[ -z "$only" || "$only" == "$n" ]] || continue
  echo "::group::[$n/${#NAMES[@]}] ${NAMES[$i]}"
  echo "===== [$n/${#NAMES[@]}] ${NAMES[$i]} ====="
  start=$SECONDS
  ${FUNCS[$i]} 2>&1 | tee "$LOG_DIR/gate-$n.log"
  gate_rc=${PIPESTATUS[0]}
  took=$((SECONDS - start))
  echo "::endgroup::"
  if [[ $gate_rc -eq 0 ]]; then
    echo "| $n | ${NAMES[$i]} | PASS | $took |" >> "$SUMMARY"
    echo "===== PASS [$n] ${NAMES[$i]} (${took}s) ====="
  else
    echo "| $n | ${NAMES[$i]} | **FAIL** | $took |" >> "$SUMMARY"
    echo "===== FAIL [$n] ${NAMES[$i]} (${took}s, exit $gate_rc) =====" >&2
    rc=1
    break
  fi
done
echo "| | total | $([[ $rc -eq 0 ]] && echo PASS || echo FAIL) | $((SECONDS - total_start)) |" >> "$SUMMARY"
cat "$SUMMARY"
[[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || cat "$SUMMARY" >> "$GITHUB_STEP_SUMMARY"
exit $rc
