#!/bin/bash
# T-0050 mutation check: one mutation per guard and per test gap this task
# closes (the kit pin, the three P-080 pins, the callers' pins, the P-089 open
# guard, and every P-093 item). Each must make a named test target FAIL with a
# failing test (a mutation that survives, or that only breaks the build,
# proves nothing). The unmutated tree must pass first (positive control).
# Each mutation is restored with `git checkout` of its file and the restore is
# verified; the script REFUSES to run when a file it mutates has uncommitted
# edits.
#
# A mutation marked "equivalent" (mutate_equivalent) is EXPECTED to survive:
# the guard it removes is redundant with another one, so no test can tell
# them apart. The script reports it and fails if it is killed instead, so a
# later change that makes the guard load-bearing is noticed.
#
#   MC_TASK=T-0050 MC_ROLE=engineer documents/evidence/T-0050/engineer/mutations.sh
#   MC_ONLY="K1 C1" ...   runs only the named mutations (after the baseline)
#
# Output base /tmp/mc-ob-$MC_TASK-$MC_ROLE; log /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log
# (also printed). Exit 0 only if every mutation was applied and killed (and
# every equivalent one survived).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK (e.g. T-0050)}"
: "${MC_ROLE:?set MC_ROLE (engineer or verifier)}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log"
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

AUTH=utility/mc_api_auth
SESS=utility/mc_session
CD=feature/comics/comics_details
FE=feature/library/library_reading_list_editor

KIT_T="//$AUTH:auth_pin_test //$AUTH:auth_races_test //$AUTH:auth_interceptor_test"
AUTH_ALL="//$AUTH:auth_pin_test //$AUTH:auth_races_test //$AUTH:auth_interceptor_test //$AUTH:auth_api_test"
SESS_T="//$SESS:session_di_test //$SESS:session_test"
CD_BDD=//$CD:bdd_test
FE_BDD=//$FE:bdd_test
FE_CONTRACT=//$FE:contract_test
FE_GUARDS=//$FE:bloc_guards_test
FORMS_T="//utility/mc_forms:form_controller_test //utility/mc_forms:wizard_controller_test"

INT=$AUTH/lib/src/auth_interceptor.dart
PIN=$AUTH/lib/src/auth_pin.dart
SESSION_DI=$SESS/lib/src/session_di_initializer.dart
CD_REPO=$CD/lib/src/domain/repository/comics_details_repository.dart
CD_BLOC=$CD/lib/src/presentation/bloc/comic_details_bloc.dart
CD_FAV=$CD/lib/src/presentation/bloc/comic_favourite_bloc.dart
CD_GUARDS=//$CD:bloc_guards_test
FE_REPO=$FE/lib/src/domain/repository/reading_list_editor_repository.dart
FE_BLOC=$FE/lib/src/presentation/bloc/reading_list_editor_bloc.dart
FE_FORM=$FE/lib/src/presentation/form/reading_list_form.dart
FE_XA=$FE/lib/src/l10n/library_reading_list_editor_en_XA.arb
FE_DE=$FE/lib/src/l10n/library_reading_list_editor_de.arb
FORM_CTRL=utility/mc_forms/lib/src/form_controller.dart
WIZARD_CTRL=utility/mc_forms/lib/src/wizard_controller.dart
HOOK=utility/mc_test_steps/lib/src/environment/signs_in_just_before_the_app_sends.dart

FILES=($INT $PIN $SESSION_DI $CD_REPO $CD_BLOC $CD_FAV $FE_REPO $FE_BLOC $FE_FORM $FE_XA $FE_DE
  $FORM_CTRL $WIZARD_CTRL $HOOK)
for f in "${FILES[@]}"; do
  if ! git diff --quiet -- "$f" || ! git diff --cached --quiet -- "$f"; then
    say "REFUSING TO RUN: $f has uncommitted edits (commit them first)"
    exit 2
  fi
done
restore_all() { git checkout -- "${FILES[@]}"; }
trap restore_all EXIT

# run <targets...>: the test output, one line per test, plus Bazel's summary.
run() { bz test --nocache_test_results --test_output=all "$@" 2>&1 | tr '\r' '\n'; }

ALL="$AUTH_ALL $SESS_T $CD_BDD $CD_GUARDS $FE_BDD $FE_CONTRACT $FE_GUARDS $FORMS_T //$CD:contract_test //$CD:flow_scope_test //$FE:flow_scope_test"
base="$(run $ALL)"
if grep -q -E "FAILED|NO STATUS|^ERROR" <<< "$base"; then
  say "BASELINE FAILS"; grep -E "FAILED|^ERROR" <<< "$base" | tee -a "$LOG"; exit 1
fi
say "baseline: PASS ($(wc -w <<< "$ALL") targets)"

rc=0
n=0
killed=0
# mutate <id> <description> <file> <python expression on s> <targets...>
# EXPECT=survive marks an equivalent mutation.
mutate() {
  local id="$1" what="$2" file="$3" expr="$4"; shift 4
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then return; fi
  n=$((n + 1))
  /usr/bin/python3 -I - "$file" "$expr" <<'EOF'
import re, sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
if t == s:
    print("MUTATION DID NOT CHANGE THE FILE"); sys.exit(3)
open(p, "w").write(t)
EOF
  if [[ $? -ne 0 ]]; then say "$id $what: NOT APPLIED"; rc=1; git checkout -- "$file"; return; fi
  [[ "$file" == *.dart ]] && fvm dart format "$file" > /dev/null
  local out; out="$(run "$@")"
  local first; first="$(grep -a -m1 -E '^  FAIL  |^[0-9:]+ \+[0-9]+ -[0-9]+: ' <<< "$out" | sed 's/^ *//')"
  if [[ -n "$first" ]]; then
    if [[ "${EXPECT:-kill}" == survive ]]; then
      say "$id $what: KILLED, but it was expected to survive (the guard is now load-bearing: $first)"; rc=1
    else
      say "$id $what: KILLED ($first)"; killed=$((killed + 1))
    fi
  elif grep -q -a -E "^ERROR|FAILED TO BUILD|Build did NOT complete" <<< "$out"; then
    say "$id $what: COMPILE ERROR (not evidence)"; rc=1
  elif [[ "${EXPECT:-kill}" == survive ]]; then
    say "$id $what: SURVIVED, as expected (equivalent: ${EQUIV_WHY:-redundant})"; killed=$((killed + 1))
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}

# --- AC1: the kit pin -----------------------------------------------------------
mutate K1 "the pin guard never rejects" $INT \
  "s.replace('if (pinned is int && pinned != _reader.epoch) {', 'if (pinned is int && pinned != _reader.epoch && pinned == -1) {')" $KIT_T
mutate K2 "the pin guard only rejects while someone is signed in" $INT \
  "s.replace('if (pinned is int && pinned != _reader.epoch) {', 'if (pinned is int && pinned != _reader.epoch && _reader.isSignedIn) {')" $KIT_T
mutate K3 "the pin failure is not the documented one" $INT \
  "s.replace(\"ApiFailure.unauthorized('The session changed')\", \"ApiFailure.unauthorized('Not allowed')\", 1)" $KIT_T
mutate K4 "a request that skips auth is held to its pin too" $INT \
  "s.replace('if (options.extra[skipAuthKey] != true) {', 'if (options.extra[skipAuthKey] != true || options.extra[mcSessionEpoch] != null) {')" $KIT_T
mutate K5 "every unpinned request is rejected as if pinned" $INT \
  "s.replace('if (pinned is int && pinned != _reader.epoch) {', 'if ((pinned is int || pinned == null) && pinned != _reader.epoch) {')" $KIT_T
mutate K6 "authPinned pins to the wrong epoch" $PIN \
  "s.replace('{mcSessionEpoch: epoch}', '{mcSessionEpoch: epoch + 1}')" $KIT_T
mutate K7 "the key is renamed" $PIN \
  "s.replace(\"'mc_api_auth.pinned_epoch'\", \"'mc_api_auth.pin'\")" $KIT_T
# --- AC3: P-080 -------------------------------------------------------------------
mutate P80-a "one refresh is shared across sessions" $INT \
  "s.replace('if (current != null && current.epoch == epoch) {', 'if (current != null) {')" $AUTH_ALL
mutate P80-b "a replay after a local sign-out mid-refresh is sent without a token" $INT \
  "s.replace('      if (epoch != _reader.epoch) {\n        // Signed out, or someone else signed in, while we waited.', '      if (epoch == -1) {\n        // Signed out, or someone else signed in, while we waited.')" $AUTH_ALL
mutate P80-c "boot reads the store even when the session file is absent" $SESSION_DI \
  "s.replace('nothingSaved = !store.existsSync(Session.defaultKey);', 'nothingSaved = false;')" $SESS_T
# --- AC2: the callers pin their writes -----------------------------------------------
mutate C1 "comics_details: the favourite PUT is not pinned" $CD_REPO \
  "s.replace('extras: authPinned(epoch)', 'extras: const {}', 1)" $CD_BDD
mutate C2 "comics_details: the favourite DELETE is not pinned" $CD_REPO \
  "(lambda i: s[:i] + s[i:].replace('extras: authPinned(epoch)', 'extras: const {}', 1))(s.index('deleteFavourite('))" $CD_BDD
mutate C3 "reading list: the create POST is not pinned" $FE_REPO \
  "s.replace('extras: authPinned(epoch)', 'extras: const {}', 1)" $FE_BDD $FE_CONTRACT
mutate C4 "reading list: the details PUT is not pinned" $FE_REPO \
  "(lambda i: s[:i] + s[i:].replace('extras: authPinned(epoch)', 'extras: const {}', 1))(s.index('_api.updateList('))" $FE_BDD $FE_CONTRACT
mutate C5 "reading list: the items PUT is not pinned" $FE_REPO \
  "(lambda i: s[:i] + s[i:].replace('extras: authPinned(epoch)', 'extras: const {}', 1))(s.index('_api.replaceItems('))" $FE_BDD $FE_CONTRACT
mutate H1 "the switch step never switches (the race would pass vacuously)" $HOOK \
  "s.replace('var fired = false;', 'var fired = true;')" $CD_BDD $FE_BDD
# --- AC3: P-089 -------------------------------------------------------------------------
mutate P89-a "a double tap on a character opens it twice" $CD_BLOC \
  "s.replace('case _OpenCharacter(:final id):\n        if (_startOpenGuard((\'character\', id.value))) {', 'case _OpenCharacter(:final id):\n        if (_startOpenGuard((\'character\', id.value)) | true) {')" $CD_BDD
mutate P89-b "a double tap on a creator opens it twice" $CD_BLOC \
  "s.replace('case _OpenCreator(:final id):\n        if (_startOpenGuard((\'creator\', id.value))) {', 'case _OpenCreator(:final id):\n        if (_startOpenGuard((\'creator\', id.value)) | true) {')" $CD_BDD
mutate P89-c "the guard is 400 ms: a tap at 499 ms opens again" $CD_BLOC \
  "s.replace('Duration(milliseconds: 500)', 'Duration(milliseconds: 400)')" $CD_BDD
mutate P89-d "the guard is 600 ms: a tap at 501 ms is swallowed" $CD_BLOC \
  "s.replace('Duration(milliseconds: 500)', 'Duration(milliseconds: 600)')" $CD_BDD
mutate P89-f "the guard is not per target: a different character within 450 ms is dropped" $CD_BLOC \
  "s.replace('_openTarget == target', 'true')" $CD_BDD
mutate P89-e "the guard timer is never started" $CD_BLOC \
  "s.replace('    _openGuard = Timer(openGuard, () {});\n', '')" $CD_BDD
# --- review round: the favourite bloc's stale-state guard ---------------------------
mutate R1-a "the favourite tap is not dropped when the session moved on (still pinned to the shown epoch)" $CD_FAV \
  "s.replace('if (epoch == null || epoch != _session.epoch) {', 'if (epoch == null) {')" $CD_GUARDS
mutate R1-b "the favourite tap is not dropped and the write pins the current epoch" $CD_FAV \
  "s.replace('if (epoch == null || epoch != _session.epoch) {', 'if (epoch == null) {').replace('      epoch: epoch,', '      epoch: _session.epoch,')" $CD_GUARDS
# --- AC3: P-093 ----------------------------------------------------------------------------
mutate P93-V01 "the create does not check the session before writing" $FE_BLOC \
  "s.replace('    if (editing == null) {\n      if (!_canWrite(epoch)) {\n        return failure(_stopped);\n      }\n', '    if (editing == null) {\n')" $FE_GUARDS
mutate P93-V02 "the details write does not check the session before writing" $FE_BLOC \
  "s.replace('    if (draft.detailsDifferFrom(saved)) {\n      if (!_canWrite(epoch)) {\n        return failure(_stopped);\n      }\n', '    if (draft.detailsDifferFrom(saved)) {\n')" $FE_GUARDS
mutate P93-V03 "the items write does not check the session before writing" $FE_BLOC \
  "s.replace('    if (draft.itemsDifferFrom(saved)) {\n      if (!_canWrite(epoch)) {\n        return failure(_stopped);\n      }\n', '    if (draft.itemsDifferFrom(saved)) {\n')" $FE_GUARDS
mutate P93-V19 "the sign-in gate trusts the app's yes without looking at the session" $FE_BLOC \
  "s.replace('if (!signedIn || !_session.isSignedIn) {', 'if (!signedIn) {')" $FE_GUARDS
mutate P93-V20-a "the Retry is not guarded by the loading flag nor by the failed state" $FE_BLOC \
  "s.replace('    if (_loading) {\n      return;\n    }\n    _loading = true;', '    _loading = true;').replace('        if (state is _LoadFailed) {', '        if (state is! _Editing) {')" $FE_GUARDS
EQUIV_WHY="a second Retry already finds the state 'loading', so the state check stops it first" EXPECT=survive \
mutate P93-V20-b "the loading flag alone is removed (equivalent)" $FE_BLOC \
  "s.replace('    if (_loading) {\n      return;\n    }\n    _loading = true;', '    _loading = true;')" $FE_GUARDS
mutate P93-V21 "the description is not mapped to its field" $FE_FORM \
  "s.replace(\"    'description' => description,\n\", '')" $FE_GUARDS
mutate P93-V22 "too_many_comics reads as 'not accepted'" $FE_FORM \
  "s.replace(\"code == 'too_many_comics'\", \"code == 'too_many'\")" $FE_GUARDS
mutate P93-V23 "the session listener adds to a closed bloc" $FE_BLOC \
  "s.replace('      if (!isClosed) {\n        add(const _SessionChanged());\n      }', '      add(const _SessionChanged());')" $FE_GUARDS
mutate P93-F1 "forms: reset keeps the server errors" $FORM_CTRL \
  "s.replace('    _rejected.clear();\n    final values', '    final values')" $FORMS_T
mutate P93-F2 "forms: reject moves the wizard while completing" $WIZARD_CTRL \
  "s.replace('  void reject(String name, FieldError error) {\n    if (_disposed || _state.isCompleting || _state.isCompleted) {', '  void reject(String name, FieldError error) {\n    if (_disposed || _state.isCompleted) {')" $FORMS_T
mutate P93-E1 "en_XA: the failed-load title is not the pseudo text" $FE_XA \
  "re.sub(r'(\"readingListEditorLoadErrorTitle\": \")[^\"]*', r'\1The reading list could not be loaded', s)" $FE_BDD
mutate P93-E2 "en_XA: the not-found title is not the pseudo text" $FE_XA \
  "re.sub(r'(\"readingListEditorNotFoundTitle\": \")[^\"]*', r'\1List not found', s)" $FE_BDD
mutate P93-DE "German: the refused-name message is English" $FE_DE \
  "re.sub(r'(\"readingListEditorNameRefused\": \")[^\"]*', r'\1You already have a list with this name.', s)" $FE_BDD

say ""
say "$killed of $n mutations behaved as expected"
cp "$LOG" "documents/evidence/$MC_TASK/$MC_ROLE/mutations.log" 2>/dev/null || true
exit $rc
