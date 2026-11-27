#!/bin/bash
# T-0057-AC2: X02, X03 and X06 (T-0054 Verifier) are killed by the suite.
#
#   X02  a push not yet located always counts as superseded
#   X03  a push is never superseded
#   X06  the page is first matched as any imperative page
#
# Each mutation runs twice on //app/wiring/app_core:flow_results_hardening_test:
#   CONTROL  the suite WITHOUT its `T-0057-AC1` group (cut out of the test
#            file for this run): the mutant must SURVIVE. This proves the gap
#            was real and that the control is a valid one.
#   SUITE    the suite as committed: the mutant must be KILLED, by a test
#            whose name contains `T-0057-AC1`.
# Outcomes: KILLED = "FAILED in" in Bazel's summary; BROKEN = "Build did NOT
# complete" or a build error (not evidence, counts as a failure);
# SURVIVED = every test passed.
# The unmutated suite must pass first. The script REFUSES a dirty tree and sets
# its restore trap before it edits anything.
#
#   tool/checks/T-0057-AC2_mutations.sh      (MC_ROLE=engineer by default)
#
# Exit 0 only if every control survived and every mutant was killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-T-0057-$ROLE}"
LOG="/tmp/mc-T-0057-$ROLE-mutations.log"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the tree is dirty (commit or remove these first):" >&2
  git status --short >&2
  exit 2
fi
: > "$LOG"

RES=app/wiring/app_core/lib/src/router/flow_results.dart
TEST=app/wiring/app_core/test/flow_results_hardening_test.dart
TARGET=//app/wiring/app_core:flow_results_hardening_test
FILES=("$RES" "$TEST")
restore_all() { git checkout -- "${FILES[@]}" 2>/dev/null; }
trap restore_all EXIT INT TERM

run() { bz test --nocache_test_results --test_timeout=900 --test_output=all "$TARGET" 2>&1 | tr '\r' '\n'; }
broken() { grep -q -a -E "Build did NOT complete|^ERROR|FAILED TO BUILD" <<< "$1"; }

base="$(run)"
if broken "$base" || grep -q -a -E "FAILED|NO STATUS" <<< "$base"; then
  say "BASELINE FAILS"
  grep -a -E "FAILED|^ERROR|Build did NOT" <<< "$base" | tee -a "$LOG"
  exit 1
fi
say "baseline: PASS"

# Cuts the `T-0057-AC1` group out of the test file (the control).
cut_group() {
  /usr/bin/python3 -I - "$TEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = s.index("  group('T-0057-AC1")
b = s.index("  group('T-0054-AC3")
open(p, "w").write(s[:a] + s[b:])
PY
}

rc=0; n=0; ok=0
# mutate ID "what" old new
mutate() {
  local id="$1" what="$2" old="$3" new="$4"
  n=$((n + 1))
  /usr/bin/python3 -I - "$RES" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1:]
s = open(path).read()
if s.count(old) != 1:
    print("PATTERN MATCHES %d TIMES: %r" % (s.count(old), old)); sys.exit(3)
open(path, "w").write(s.replace(old, new))
PY
  if [[ $? -ne 0 ]]; then
    say "$id $what: NOT APPLIED"; rc=1; restore_all; return
  fi
  fvm dart format "$RES" > /dev/null

  # CONTROL: the suite without the new tests must let the mutant survive.
  cut_group
  local out ctl=0
  out="$(run)"
  if broken "$out"; then
    say "$id CONTROL: BROKEN (build failed: not evidence)"; rc=1; ctl=1
  elif grep -q -a "FAILED in" <<< "$out"; then
    say "$id CONTROL: KILLED by $(grep -a -m1 -E '^  FAIL  ' <<< "$out" | sed 's/^ *//') (the gap is not what T-0057 pins)"; rc=1; ctl=1
  elif grep -q -a "TIMEOUT in" <<< "$out"; then
    say "$id CONTROL: TIMEOUT (not a survival)"; rc=1; ctl=1
  else
    say "$id CONTROL (suite without the T-0057-AC1 tests): SURVIVED, as expected"
  fi
  git checkout -- "$TEST"

  # SUITE: the suite as committed must kill it, by a T-0057-AC1 test.
  out="$(run)"
  if broken "$out"; then
    say "$id $what: BROKEN (build failed: not evidence)"; rc=1
  elif grep -q -a "FAILED in" <<< "$out"; then
    local fails; fails="$(grep -a -E '^  FAIL  ' <<< "$out" | sed 's/^ *//')"
    if grep -q -F -- "T-0057-AC1" <<< "$fails"; then
      say "$id $what: KILLED ($(head -1 <<< "$fails"))"
      [[ $ctl -eq 0 ]] && ok=$((ok + 1))
    else
      say "$id $what: KILLED, BUT NOT BY A T-0057-AC1 TEST. First: $(head -1 <<< "$fails")"; rc=1
    fi
  elif grep -q -a "TIMEOUT in" <<< "$out"; then
    say "$id $what: TIMEOUT (not a kill)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  restore_all
  git diff --quiet -- "${FILES[@]}" || { say "RESTORE FAILED"; rc=1; }
}

mutate X02 "a push not yet located always counts as superseded" \
  $'      final info = provider.value.state;\n      return !(info' \
  $'      final info = provider.value.state;\n      return true || !(info'
mutate X03 "a push is never superseded" \
  $'      final info = provider.value.state;\n      return !(info' \
  $'      final info = provider.value.state;\n      return false && !(info'
mutate X06 "the page is first matched as any imperative page" \
  '? push != null && identical(match.completer.future, push)' '? push != null'

say "mutations: $n, controls survived and mutants killed: $ok"
if [[ $n -eq $ok && $rc -eq 0 ]]; then say "ALL KILLED, ALL CONTROLS SURVIVED"; exit 0; fi
say "FAILED"
exit 1
