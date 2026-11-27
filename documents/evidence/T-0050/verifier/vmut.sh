#!/bin/bash
# T-0050 Verifier's own mutations (not the engineer's). Runs in the Verifier's
# probe worktree: vmut.sh <worktree> [ids...]. Each mutation is restored with
# git checkout and the restore is verified.
set -uo pipefail
W="$1"; shift
ONLY=" ${*:-} "
cd "$W" || exit 2
OB=/tmp/mc-ob-T-0050-verifier-probe
LOG=/tmp/mc-T-0050-verifier-vmut.log
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
AUTH=utility/mc_api_auth
CD=feature/comics/comics_details
FE=feature/library/library_reading_list_editor
INT=$AUTH/lib/src/auth_interceptor.dart
PIN=$AUTH/lib/src/auth_pin.dart
CD_FAV=$CD/lib/src/presentation/bloc/comic_favourite_bloc.dart
CD_BLOC=$CD/lib/src/presentation/bloc/comic_details_bloc.dart
FE_BLOC=$FE/lib/src/presentation/bloc/reading_list_editor_bloc.dart
FE_REPO=$FE/lib/src/domain/repository/reading_list_editor_repository.dart
HOOK=utility/mc_test_steps/lib/src/environment/signs_in_just_before_the_app_sends.dart
KIT="//$AUTH:auth_pin_test //$AUTH:auth_races_test //$AUTH:auth_interceptor_test //$AUTH:auth_api_test"
CDT="//$CD:bdd_test //$CD:bloc_guards_test //$CD:contract_test"
FET="//$FE:bdd_test //$FE:contract_test //$FE:bloc_guards_test"

mutate() {  # mutate <id> <expect kill|survive> <what> <file> <py expr> <targets...>
  local id="$1" expect="$2" what="$3" file="$4" expr="$5"; shift 5
  [[ "$ONLY" != "  " && "$ONLY" != *" $id "* ]] && return
  /usr/bin/python3 -I - "$file" "$expr" <<'EOF' || { say "$id: NOT APPLIED"; git checkout -- "$file"; return; }
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
if t == s:
    sys.exit(3)
open(p, "w").write(t)
EOF
  fvm dart format "$file" > /dev/null
  local out
  out="$(tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all "$@" 2>&1 | tr '\r' '\n')"
  local fails
  fails="$(grep -a -E '^  FAIL  |^[0-9:]+ \+[0-9]+ -[0-9]+: .*\[E\]' <<< "$out" | sed 's/^ *//' | sort -u | head -6)"
  local verdict
  if [[ -n "$fails" ]]; then verdict=KILLED
  elif grep -q -a -E "^ERROR|Build did NOT complete" <<< "$out"; then verdict="BUILD ERROR (not evidence)"
  else verdict=SURVIVED; fi
  say "$id [$expect] $what: $verdict"
  [[ -n "$fails" ]] && sed 's/^/    /' <<< "$fails" | tee -a "$LOG"
  git checkout -- "$file"
  git diff --quiet -- "$file" || say "RESTORE FAILED: $file"
}

mutate M1 kill "pin compared with the epoch the bearer was applied for, not the session's" $INT \
  "s.replace('if (pinned is int && pinned != _reader.epoch) {', 'if (pinned is int && pinned != (options.extra[_epoch] ?? pinned)) {')" $KIT
mutate M2 kill "a stale pin is sent without a bearer instead of rejected" $INT \
  "s.replace('''        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: const ApiFailure.unauthorized('The session changed'),
          ),
        );
      }
      final ours''', '''        options.headers.remove('Authorization');
        return handler.next(options);
      }
      final ours''', 1)" $KIT
mutate M3 kill "only the first send is held to the pin (replays and retries exempt)" $INT \
  "s.replace('if (pinned is int && pinned != _reader.epoch) {', 'if (pinned is int && pinned != _reader.epoch && options.extra[_applied] != true) {')" $KIT
mutate M4 kill "authPinned stores the epoch as a String (silently unpinned)" $PIN \
  "s.replace('{mcSessionEpoch: epoch}', '{mcSessionEpoch: \'\$epoch\'}')" $KIT
mutate M5 kill "favourite: after a sign-in from the tap the shown epoch is not updated" $CD_FAV \
  "s.replace('''      _shownEpoch = epoch;
      final failure = fresh''', '''      final failure = fresh''')" $CDT
mutate M6 kill "favourite: no reload at the end of a tap whose session moved on" $CD_FAV \
  "s.replace('''          _busy = false;
        }
        if (_session.epoch != _shownEpoch) {
          await _load(emit);
        }''', '''          _busy = false;
        }''')" $CDT
mutate M7 survive "editor create pins the session's current epoch (no await after _canWrite: equivalent)" $FE_BLOC \
  "s.replace('_repository.create(draft, epoch: epoch)', '_repository.create(draft, epoch: _session.epoch)')" $FET
mutate M8 kill "open guard: timer not cancelled in close()" $CD_BLOC \
  "s.replace('''  Future<void> close() {
    _openGuard?.cancel();''', '''  Future<void> close() {''')" $CDT
mutate M9 kill "open guard keyed by id only (a creator with a character's id is dropped)" $CD_BLOC \
  "s.replace('_openTarget == target', '_openTarget?.\$2 == target.\$2')" $CDT
mutate M10 kill "race step: hook at the END of the chain (after the auth interceptor)" $HOOK \
  "s.replace('interceptors.insert(0, hook);', 'interceptors.add(hook);')" "//$CD:bdd_test" "//$FE:bdd_test"
mutate M11 kill "editor create not pinned, BDD only (no contract test)" $FE_REPO \
  "s.replace('extras: authPinned(epoch)', 'extras: const {}', 1)" "//$FE:bdd_test"
mutate M12 kill "editor items PUT not pinned, BDD only" $FE_REPO \
  "(lambda i: s[:i] + s[i:].replace('extras: authPinned(epoch)', 'extras: const {}', 1))(s.index('_api.replaceItems('))" "//$FE:bdd_test"
say "done"
