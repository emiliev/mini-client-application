#!/bin/bash
# T-0063: targeted mutation check (ADR-0015: about 15 mutants where a silent
# test gap would hurt): the session epoch and the pin, the sign-in merge rule,
# the 409 re-apply, persistence, and the reduce-motion wiring. The first runs
# covered 74 mutants (mutations_run1.log, mutations_run2.log); this file keeps
# the 16 in those areas.
#
# Every mutation edits one source file, runs the named test targets, and must
# make a test FAIL ("FAILED in" in Bazel's summary). Outcomes:
#   KILLED    a test failed.
#   BROKEN    the build did not complete ("Build did NOT complete", a compile,
#             analyzer or format error): NOT evidence, counted as a failure.
#   TIMEOUT   a test timed out: not a kill, counted as a failure.
#   SURVIVED  every test passed: a hole in the tests.
# The unmutated tree must pass first. The script REFUSES a dirty tree (any
# uncommitted or untracked file) and sets its restore trap before it edits
# anything; after each mutation the file is restored with `git checkout` and
# the restore is verified.
#
#   MC_TASK=T-0063 MC_ROLE=engineer documents/evidence/T-0063/engineer/mutations.sh
#   MC_ONLY="M01 W2" ...   only the named mutations (after the baseline)
#   MC_CHECK_ONLY=1 ...    only check that every pattern applies (no Bazel)
#
# Exit 0 only if every mutation was applied and killed. The log goes to
# /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TASK="${MC_TASK:-T-0063}"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-$TASK-$ROLE}"
LOG="/tmp/mc-$TASK-$ROLE-mutations.log"
CHECK_ONLY="${MC_CHECK_ONLY:-}"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

# Also in check-only mode: the restore trap checks the files out, which
# would drop uncommitted work in them.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the tree is dirty (commit or remove these first):" >&2
  git status --short >&2
  exit 2
fi
: > "$LOG"

A=utility/mc_appearance/lib/src
FS=feature/settings/settings_appearance/lib/src
AC=app/wiring/app_core/lib/src
FILES=(
  "$A/appearance.dart" "$A/preferences_api.dart" "$A/appearance_preferences.dart"
  "$A/appearance_store.dart" "$A/appearance_di_initializer.dart"
  utility/mc_storage/lib/src/file_store.dart utility/mc_ds_theme/lib/src/mc_theme.dart
  "$AC/shell/mc_app.dart" "$AC/shell/app_appearance.dart" "$AC/di/root_initializers.dart"
  "$AC/locations/app_locations.dart"
  "$FS/presentation/bloc/appearance_bloc.dart" "$FS/presentation/page/appearance_page.dart"
  "$FS/presentation/widget/sync_status.dart" "$FS/presentation/widget/settings_spacing.dart"
  "$FS/flow/settings_appearance_flow.dart"
  app/wiring/account_wiring/lib/src/routes/settings_routes.dart
  app/wiring/account_wiring/lib/src/navigators/settings_appearance_navigator_impl.dart
  app/mini_client/lib/src/router/app_routes.dart
  utility/mc_test_utils/lib/src/test_container.dart
)
restore_all() { git checkout -- "${FILES[@]}" 2>/dev/null; }
trap restore_all EXIT INT TERM

T_APP="//utility/mc_appearance:preferences_test //utility/mc_appearance:local_test //utility/mc_appearance:sync_test //utility/mc_appearance:races_test //utility/mc_appearance:di_test"
T_FS=//utility/mc_storage:file_store_test
T_FEAT="//feature/settings/settings_appearance:bdd_test //feature/settings/settings_appearance:flow_scope_test //feature/settings/settings_appearance:contract_test"
T_SHELL="//app/wiring/app_core:appearance_shell_test //utility/mc_ds_theme:theme_test"
T_WIRE="//app/wiring/account_wiring:routes_test //app/mini_client:settings_route_test"
T_TU="//utility/mc_test_utils:isolation_test"

run() { bz test --nocache_test_results --test_timeout=900 "$@" 2>&1 | tr '\r' '\n'; }

if [[ -z "$CHECK_ONLY" ]]; then
  base="$(run $T_APP $T_FS $T_FEAT $T_SHELL $T_WIRE $T_TU)"
  if grep -q -a -E "FAILED|NO STATUS|^ERROR|Build did NOT complete" <<< "$base"; then
    say "BASELINE FAILS"
    grep -a -E "FAILED|^ERROR|Build did NOT" <<< "$base" | tee -a "$LOG"
    exit 1
  fi
  say "baseline: PASS"
fi

rc=0; n=0; killed=0
# mutate ID "what" file "targets" old new [old new ...]
mutate() {
  local id="$1" what="$2" file="$3" targets="$4"; shift 4
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then return; fi
  n=$((n + 1))
  /usr/bin/python3 -I - "$file" "$@" <<'EOF'
import sys
path, pairs = sys.argv[1], sys.argv[2:]
s = open(path).read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if s.count(old) != 1:
        print("PATTERN MATCHES %d TIMES: %r" % (s.count(old), old)); sys.exit(3)
    s = s.replace(old, new)
open(path, "w").write(s)
EOF
  if [[ $? -ne 0 ]]; then
    say "$id $what: NOT APPLIED"; rc=1; git checkout -- "$file"; return
  fi
  if [[ -n "$CHECK_ONLY" ]]; then
    say "$id $what: applies"; git checkout -- "$file"; return
  fi
  [[ "$file" == *.dart ]] && fvm dart format "$file" > /dev/null
  local out; out="$(run $targets)"
  if grep -q -a -E "Build did NOT complete|^ERROR|FAILED TO BUILD" <<< "$out"; then
    say "$id $what: BROKEN (build failed: not evidence)"; rc=1
  elif grep -q -a "FAILED in" <<< "$out"; then
    local first; first="$(grep -a -m1 'FAILED in' <<< "$out" | awk '{print $1}')"
    say "$id $what: KILLED ($first)"; killed=$((killed + 1))
  elif grep -q -a "TIMEOUT in" <<< "$out"; then
    say "$id $what: TIMEOUT (not a kill)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}

# --- the session epoch, the merge rule, the 409 policy, persistence, the shell
P="$A/appearance.dart"
mutate A01 "answers of a gone epoch are applied" "$P" "$T_APP" \
  "bool _isCurrent(int epoch) => !_disposed && _session.epoch == epoch;" \
  "bool _isCurrent(int epoch) => !_disposed;"
mutate A02 "a change does not look at an undelivered session change first" "$P" "$T_APP" \
  "    // belongs to the session that is current now.
    _observeEpoch();" "    // belongs to the session that is current now."
# --- the merge rule ---------------------------------------------------------
mutate A05 "another user's pending settings are kept" "$P" "$T_APP" \
  "if (_pendingFor != null && _pendingFor != userId) {" \
  "if ((_pendingFor != null && _pendingFor != userId) & false) {"
mutate A06 "sign-out keeps what was pending" "$P" "$T_APP" \
  "      if (_pendingFor != null) {
        _pending.clear();" "      if ((_pendingFor != null) & false) {
        _pending.clear();"
mutate A07 "the account wins over pending settings too" "$P" "$T_APP $T_FEAT" \
  "_preferences = copy.preferences.overlay(_preferences, _pending);" \
  "_preferences = copy.preferences;"
mutate A08 "pending settings are not adopted by the account that signs in" "$P" "$T_APP" \
  "      // This user's own, or made while signed out: it goes to this account.
      _pendingFor = userId;" "      // This user's own, or made while signed out: it goes to this account.
      _pendingFor = null;"
mutate A09 "a lost write is never re-sent" "$P" "$T_APP $T_WIRE" \
  "            account.version < _seenVersion!) {" \
  "            (account.version < _seenVersion!) & false) {"
# --- writes and the 409 policy ------------------------------------------------
mutate A16 "a PATCH always says ifVersion 0" "$P" "$T_APP" \
  "        ifVersion: account.version," "        ifVersion: 0,"
mutate A17 "a setting changed again while its PATCH was out is confirmed anyway" "$P" "$T_APP" \
  "                sending.contains(s) &&
                _preferences.wireValue(s) == sent.wireValue(s)," \
  "                sending.contains(s),"
mutate A18 "a 409 is never retried" "$P" "$T_APP $T_FEAT" \
  "          if (conflicts > 1) {" "          if (conflicts > 0) {"
mutate A19 "a second 409 is retried too" "$P" "$T_APP" \
  "          if (conflicts > 1) {" "          if (conflicts > 2) {"
mutate A21 "a conflict is always reported as resolved with another device" "$P" "$T_APP $T_FEAT" \
  "              .isNotEmpty) {
            tookOtherChanges = true;" "              .isEmpty) {
            tookOtherChanges = true;"
P="$A/preferences_api.dart"
mutate A26 "the write is not pinned to its epoch" "$P" "$T_APP $T_FEAT" \
  "          extra: authPinned(epoch)," "          extra: const <String, Object?>{},"
P="$A/appearance_preferences.dart"
P="$A/appearance_store.dart"
P="$A/appearance_di_initializer.dart"
# --- mc_storage -------------------------------------------------------------------
P=utility/mc_storage/lib/src/file_store.dart
mutate S01 "writeSync never renames into place" "$P" "$T_FS $T_APP" \
  "          ..writeAsStringSync(jsonEncode(value), flush: true)
          ..renameSync(target.path);" "          ..writeAsStringSync(jsonEncode(value), flush: true);"
# --- the shell (app_core, mc_ds_theme) ------------------------------------------
P="$AC/shell/mc_app.dart"
mutate B05 "reduce motion never reaches the routed app" "$P" "$T_SHELL" \
  "            data: _appearance.applyMotion(MediaQuery.of(context))," \
  "            data: MediaQuery.of(context),"
P="$AC/shell/app_appearance.dart"
mutate B08 "reduce motion off turns the platform's setting off" "$P" "$T_SHELL" \
  "      reduceMotion ? data.copyWith(disableAnimations: true) : data;" \
  "      data.copyWith(disableAnimations: reduceMotion);"
P="$AC/di/root_initializers.dart"
P=utility/mc_ds_theme/lib/src/mc_theme.dart
# --- the feature ------------------------------------------------------------------
P="$FS/presentation/bloc/appearance_bloc.dart"
P="$FS/presentation/page/appearance_page.dart"
P="$FS/presentation/widget/sync_status.dart"
P="$FS/presentation/widget/settings_spacing.dart"
P="$FS/flow/settings_appearance_flow.dart"
# --- the wiring and the app ----------------------------------------------------------
P=app/wiring/account_wiring/lib/src/routes/settings_routes.dart
P=app/wiring/account_wiring/lib/src/navigators/settings_appearance_navigator_impl.dart
P="$AC/locations/app_locations.dart"
P=app/mini_client/lib/src/router/app_routes.dart
P=utility/mc_test_utils/lib/src/test_container.dart
say ""
say "mutations: $n, killed: $killed"
[[ $rc -eq 0 && $n -eq $killed ]] && say "RESULT: PASS" || { say "RESULT: FAIL"; exit 1; }
