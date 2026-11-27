#!/bin/bash
# T-0062-AC4 (P-114): the two new overlays tests kill their mutants.
#
#   M1  mc_sheet.dart: the handle's tap uses `pop` instead of `maybePop`
#   M2  mc_sheet.dart: the handle's semantics tap uses `pop` instead of `maybePop`
#   M3  mc_sheet.dart: both of them use `pop`
#   M4  mc_toast.dart: mcToastDuration is 3 s
#   M5  mc_toast.dart: mcToastDuration is 5 s
#
# Each mutation runs twice on //utility/mc_ds_overlays:overlays_test:
#   CONTROL  the suite WITHOUT the `T-0062-AC4` tests (test filter): the mutant
#            must SURVIVE, which proves the gap was real (P-114). Not required
#            for M4 and M5 (see `mutate`).
#   SUITE    only the `T-0062-AC4` tests: the mutant must be KILLED.
# KILLED = "FAILED in" in Bazel's summary; BROKEN = a build error (not
# evidence, counts as a failure); SURVIVED = every test passed. Also runs the
# unmutated suite first (must pass). REFUSES a dirty tree and sets its restore
# trap before it edits anything.
#
#   tool/checks/T-0062-AC4_mutations.sh      (MC_ROLE=engineer by default)
#
# Exit 0 only if every control survived and every mutant was killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-T-0062-$ROLE}"
LOG="${MC_MUTATION_LOG:-/tmp/mc-T-0062-$ROLE-mutations.log}"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the tree is dirty (commit or remove these first):" >&2
  git status --short >&2
  exit 2
fi
: > "$LOG"

SHEET=utility/mc_ds_overlays/lib/src/mc_sheet.dart
TOAST=utility/mc_ds_overlays/lib/src/mc_toast.dart
TARGET=//utility/mc_ds_overlays:overlays_test
restore_all() { git checkout -- "$SHEET" "$TOAST" 2>/dev/null; }
trap restore_all EXIT INT TERM

# run <filter>: filter is a regex on the test name.
run() { bz test --nocache_test_results --test_timeout=900 --test_output=errors --test_filter="$1" "$TARGET" 2>&1 | tr '\r' '\n'; }
broken() { grep -q -a -E "Build did NOT complete|^ERROR|FAILED TO BUILD" <<< "$1"; }
verdict() {
  if broken "$1"; then echo BROKEN
  elif grep -q -a -E "FAILED in|NO STATUS" <<< "$1"; then echo KILLED
  elif grep -q -a "PASSED in" <<< "$1"; then echo SURVIVED
  else echo BROKEN; fi
}

NEW='T-0062-AC4'
OLD='^(?!.*T-0062-AC4)'

base="$(run "$NEW")"
[[ "$(verdict "$base")" == SURVIVED ]] || { say "BASELINE (new tests) FAILS"; exit 1; }
base="$(run "$OLD")"
[[ "$(verdict "$base")" == SURVIVED ]] || { say "BASELINE (old tests) FAILS"; exit 1; }
say "baseline: both filters PASS (unmutated)"

ok=1
# mutate <name> <file> <python-expr transforming s> [control-informational]
# A 5 s toast is also killed by the older "stays 4 s, with an action 8 s"
# test (its 4.2 s gone check), so for the toast mutants the control is only
# reported and the SUITE verdict is what counts.
mutate() {
  local name="$1" file="$2" expr="$3" info="${4:-}" c s
  restore_all
  /usr/bin/python3 -I - "$file" "$expr" <<'PY' || { say "$name: MUTATION DID NOT APPLY"; ok=0; return; }
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
if t == s:
    sys.exit(1)
open(p, "w").write(t)
PY
  c="$(verdict "$(run "$OLD")")"
  s="$(verdict "$(run "$NEW")")"
  say "$name: CONTROL (without the new tests) $c; SUITE (new tests) $s"
  [[ "$s" == KILLED ]] || ok=0
  [[ -n "$info" || "$c" == SURVIVED ]] || ok=0
  restore_all
}

mutate "M1 handle tap: pop" "$SHEET" \
  "s.replace('''onTap: () => Navigator.of(context).maybePop(),
        child: bar,''', '''onTap: () => Navigator.of(context).pop(),
        child: bar,''')"
mutate "M2 semantics tap: pop" "$SHEET" \
  "s.replace('''onTap: () => Navigator.of(context).maybePop(),
      excludeSemantics''', '''onTap: () => Navigator.of(context).pop(),
      excludeSemantics''')"
mutate "M3 both: pop" "$SHEET" "s.replace('Navigator.of(context).maybePop()', 'Navigator.of(context).pop()')"
mutate "M4 toast 3 s" "$TOAST" "s.replace('mcToastDuration = Duration(seconds: 4)', 'mcToastDuration = Duration(seconds: 3)')" info
mutate "M5 toast 5 s" "$TOAST" "s.replace('mcToastDuration = Duration(seconds: 4)', 'mcToastDuration = Duration(seconds: 5)')" info

[[ -z "$(git status --porcelain)" ]] || { say "TREE NOT RESTORED"; ok=0; }
if [[ "$ok" == 1 ]]; then say "RESULT: PASS (every control survived, every mutant killed)"; exit 0; fi
say "RESULT: FAIL"; exit 1
