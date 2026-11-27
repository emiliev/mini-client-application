#!/bin/bash
# T-0063: mutation check of the settings_appearance ST exemplar, mc_appearance and the kit support.
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

# --- mc_appearance: the session epoch --------------------------------------
P="$A/appearance.dart"
mutate A01 "answers of a gone epoch are applied" "$P" "$T_APP" \
  "bool _isCurrent(int epoch) => !_disposed && _session.epoch == epoch;" \
  "bool _isCurrent(int epoch) => !_disposed;"
mutate A02 "a change does not look at an undelivered session change first" "$P" "$T_APP" \
  "    // belongs to the session that is current now.
    _observeEpoch();" "    // belongs to the session that is current now."
mutate A03 "a same-user re-sign-in is not followed (no epoch stream)" "$P" "$T_APP" \
  "      _epochSubscription = session.epochChanges.listen((_) => _observeEpoch());" \
  "      _epochSubscription = null;"
mutate A04 "dispose does not stop the appearance" "$P" "$T_APP" \
  "    _disposed = true;" "    _disposed = _disposed;"
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
mutate A10 "the version seen is compared for any user" "$P" "$T_APP" \
  "        if (_seenFor == userId &&" "        if (userId == userId &&"
mutate A11 "an account that moved on is overwritten" "$P" "$T_APP" \
  "            account.version < _seenVersion!) {" \
  "            account.version != _seenVersion!) {"
mutate A12 "the version seen is not remembered" "$P" "$T_APP" \
  "    _seenVersion = copy.version;" "    _seenVersion = _seenVersion;"
mutate A13 "a no-op change still saves, syncs and announces" "$P" "$T_APP" \
  "    if (changed.isEmpty) {
      return Future<void>.value();
    }
    _preferences = next;" "    if (changed.isEmpty & false) {
      return Future<void>.value();
    }
    _preferences = next;"
mutate A14 "the follow-account switch is ignored" "$P" "$T_APP" \
  "String? get _userId => _followAccount ? _session.userId : null;" \
  "String? get _userId => _session.userId;"
# --- writes and the 409 policy ------------------------------------------------
mutate A15 "a PATCH sends every setting" "$P" "$T_APP $T_FEAT" \
  "        settings: sending," "        settings: AppearanceSetting.values.toSet(),"
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
mutate A20 "another device's change is never reported" "$P" "$T_APP $T_FEAT" \
  "            tookOtherChanges = true;" "            tookOtherChanges = false;"
mutate A21 "a conflict is always reported as resolved with another device" "$P" "$T_APP $T_FEAT" \
  "              .isNotEmpty) {
            tookOtherChanges = true;" "              .isEmpty) {
            tookOtherChanges = true;"
mutate A22 "retry also syncs when nothing failed" "$P" "$T_APP" \
  "    if (_userId == null || _status != AppearanceSyncStatus.offline) {" \
  "    if (_userId == null) {"
mutate A23 "a save failure is not retried by retry" "$P" "$T_APP" \
  "    if (_saveFailure != null) {
      _save();" "    if (_saveFailure != null) {"
mutate A24 "after a failed save, an equal record is not written again" "$P" "$T_APP" \
  "    if (_saveFailure == null && saved.sameAs(record)) {" \
  "    if (saved.sameAs(record)) {"
P="$A/preferences_api.dart"
mutate A25 "a 409 is a failure, its current is never read" "$P" "$T_APP $T_FEAT" \
  "(status == 409 || status >= 200 && status < 300)" "(status >= 200 && status < 300)"
mutate A26 "the write is not pinned to its epoch" "$P" "$T_APP $T_FEAT" \
  "          extra: authPinned(epoch)," "          extra: const <String, Object?>{},"
mutate A27 "a copy without an int version is taken" "$P" "$T_APP" \
  "if (preferences == null || version is! int) {" "if (preferences == null) {"
P="$A/appearance_preferences.dart"
mutate A28 "a reduceMotion that is not a bool is read" "$P" "$T_APP" \
  "if (themeMode == null || density == null || reduceMotion is! bool) {" \
  "if (themeMode == null || density == null) {"
mutate A29 "overlay ignores the density" "$P" "$T_APP" \
  "      density: keys.contains(AppearanceSetting.density)" \
  "      density: keys.contains(AppearanceSetting.reduceMotion)"
P="$A/appearance_store.dart"
mutate A30 "an empty pendingFor is an owner" "$P" "$T_APP" \
  "pendingFor: owner is String && owner.isNotEmpty ? owner : null," \
  "pendingFor: owner is String ? owner : null,"
mutate A31 "a seen version without its user is kept" "$P" "$T_APP" \
  "final seen = seenVersion is int && seenFor is String && seenFor.isNotEmpty;" \
  "final seen = seenVersion is int;"
P="$A/appearance_di_initializer.dart"
mutate A32 "the initializer swaps follow and device-only" "$P" "$T_APP $T_TU $T_FEAT" \
  ": this._(followAccount ? _follow : _deviceOnly);" ": this._(followAccount ? _deviceOnly : _follow);"
# --- mc_storage -------------------------------------------------------------------
P=utility/mc_storage/lib/src/file_store.dart
mutate S01 "writeSync never renames into place" "$P" "$T_FS $T_APP" \
  "          ..writeAsStringSync(jsonEncode(value), flush: true)
          ..renameSync(target.path);" "          ..writeAsStringSync(jsonEncode(value), flush: true);"
mutate S02 "readSync never reads" "$P" "$T_FS $T_APP" \
  "      return success(jsonDecode(_file(key).readAsStringSync()));" \
  "      return success(null);"
mutate S03 "a failed writeSync leaves its temp file" "$P" "$T_FS" \
  "        if (temp.existsSync()) {
          temp.deleteSync();
        }" "        if (temp.existsSync()) {}"
# --- the shell (app_core, mc_ds_theme) ------------------------------------------
P="$AC/shell/mc_app.dart"
mutate B01 "McApp does not follow later changes" "$P" "$T_SHELL" \
  "        setState(() => _applyAppearance(snapshot.preferences));" "        setState(() {});"
mutate B02 "McApp never reads the appearance at boot" "$P" "$T_SHELL $T_WIRE" \
  "      _followAppearance();
" ""
mutate B03 "the light theme ignores the density" "$P" "$T_SHELL" \
  "          theme: McTheme.of(McThemeVariant.light, visualDensity: density)," \
  "          theme: McTheme.light,"
mutate B04 "the dark theme ignores the density" "$P" "$T_SHELL" \
  "          darkTheme: McTheme.of(McThemeVariant.dark, visualDensity: density)," \
  "          darkTheme: McTheme.dark,"
mutate B05 "reduce motion never reaches the routed app" "$P" "$T_SHELL" \
  "            data: _appearance.applyMotion(MediaQuery.of(context))," \
  "            data: MediaQuery.of(context),"
mutate B06 "McApp looks for no appearance in the root" "$P" "$T_SHELL $T_WIRE" \
  "      ? diContainer<AppearanceReader>()
      : null;" "      ? null
      : null;"
P="$AC/shell/app_appearance.dart"
mutate B07 "Dark maps to light" "$P" "$T_SHELL $T_WIRE" \
  "    AppearanceThemeMode.dark => ThemeMode.dark," "    AppearanceThemeMode.dark => ThemeMode.light,"
mutate B08 "reduce motion off turns the platform's setting off" "$P" "$T_SHELL" \
  "      reduceMotion ? data.copyWith(disableAnimations: true) : data;" \
  "      data.copyWith(disableAnimations: reduceMotion);"
mutate B09 "Compact maps to the standard density" "$P" "$T_SHELL" \
  "    AppearanceDensity.compact => VisualDensity.compact," "    AppearanceDensity.compact => null,"
P="$AC/di/root_initializers.dart"
mutate B10 "the root list has no appearance" "$P" "$T_WIRE" \
  "    const AppearanceDIInitializer(),
" ""
P=utility/mc_ds_theme/lib/src/mc_theme.dart
mutate B11 "McTheme drops the density" "$P" "$T_SHELL" \
  "      visualDensity: visualDensity,
" ""
# --- the feature ------------------------------------------------------------------
P="$FS/presentation/bloc/appearance_bloc.dart"
mutate C01 "choosing the theme already in use tracks and saves" "$P" "$T_FEAT" \
  "        if (_current?.themeMode != mode) {" "        if ((_current?.themeMode != mode) | true) {"
mutate C02 "choosing the density already in use tracks" "$P" "$T_FEAT" \
  "        if (_current?.density != density) {" "        if ((_current?.density != density) | true) {"
mutate C03 "switching reduce motion to its value tracks" "$P" "$T_FEAT" \
  "        if (_current?.reduceMotion != on) {" "        if ((_current?.reduceMotion != on) | true) {"
mutate C04 "a reset of the defaults tracks" "$P" "$T_FEAT" \
  "        if (_current != AppearancePreferences.defaults) {" \
  "        if ((_current != AppearancePreferences.defaults) | true) {"
mutate C05 "the theme choice is not tracked" "$P" "$T_FEAT" \
  "          _tracker.themeModeChanged(mode);
" ""
mutate C06 "the density choice is not tracked" "$P" "$T_FEAT" \
  "          _tracker.densityChanged(density);
" ""
mutate C07 "the reduce motion switch is not tracked" "$P" "$T_FEAT" \
  "          _tracker.reduceMotionChanged(on: on);
" ""
mutate C08 "the reset is not tracked" "$P" "$T_FEAT" \
  "          _tracker.resetToDefaults();
" ""
mutate C09 "the theme choice never reaches the appearance" "$P" "$T_FEAT" \
  "          _apply(_appearance.change(themeMode: mode), emit);" "          _apply(Future<void>.value(), emit);"
mutate C10 "the reset never reaches the appearance" "$P" "$T_FEAT" \
  "          _apply(_appearance.reset(), emit);" "          _apply(Future<void>.value(), emit);"
mutate C11 "Retry never reaches the appearance" "$P" "$T_FEAT" \
  "        _apply(_appearance.retry(), emit);" "        _apply(Future<void>.value(), emit);"
mutate C12 "a double tap asks to sign in twice" "$P" "$T_FEAT" \
  "    if (_signingIn ||" "    if ((_signingIn & false) ||"
mutate C13 "the state is not shown again after the sign-in answer" "$P" "$T_FEAT" \
  "    // Whatever the answer: the appearance shows the session now current.
    _show(emit);" "    // Whatever the answer: the appearance shows the session now current."
mutate C14 "the appearance's changes are not followed" "$P" "$T_FEAT" \
  "            add(const _Changed());" "            assert(isClosed || !isClosed);"
mutate C15 "a save failure is never a failure state" "$P" "$T_FEAT" \
  "    final failure = snapshot.saveFailure;" "    final failure = _signingIn ? snapshot.saveFailure : null;"
mutate C16 "About themes does not open the explainer" "$P" "$T_FEAT" \
  "        _flow.update((s) => s.copyWith(aboutOpen: true));" "        _flow.update((s) => s.copyWith(aboutOpen: false));"
P="$FS/presentation/page/appearance_page.dart"
mutate D01 "Cancel resets too" "$P" "$T_FEAT" \
  "    if (confirmed && !bloc.isClosed) {" "    if (!bloc.isClosed) {"
P="$FS/presentation/widget/sync_status.dart"
mutate D02 "Retry is not offered offline" "$P" "$T_FEAT" \
  "        if (sync == AppearanceSyncStatus.offline) ...[" "        if (sync == AppearanceSyncStatus.conflictResolved) ...["
mutate D03 "Sync across devices is offered signed in" "$P" "$T_FEAT" \
  "        if (sync == AppearanceSyncStatus.local) ...[" "        if (sync != AppearanceSyncStatus.offline) ...["
mutate D04 "offline reads as synced" "$P" "$T_FEAT" \
  "      AppearanceSyncStatus.offline => l10n.settingsAppearanceSyncOffline," \
  "      AppearanceSyncStatus.offline => l10n.settingsAppearanceSyncSynced,"
P="$FS/presentation/widget/settings_spacing.dart"
mutate D05 "the gaps ignore the density" "$P" "$T_FEAT" \
  "  double get groupGap => isCompact ? McSpacing.md : McSpacing.xl;" \
  "  double get groupGap => McSpacing.xl;"
P="$FS/flow/settings_appearance_flow.dart"
mutate D06 "the explainer page is never built" "$P" "$T_FEAT" \
  "          if (state.aboutOpen)" "          if (state.aboutOpen && state != state)"
# --- the wiring and the app ----------------------------------------------------------
P=app/wiring/account_wiring/lib/src/routes/settings_routes.dart
mutate E01 "the route has another path" "$P" "$T_WIRE" \
  "  path: '/settings/appearance'," "  path: '/settings/look',"
P=app/wiring/account_wiring/lib/src/navigators/settings_appearance_navigator_impl.dart
mutate E02 "the sign-in sheet gives another reason" "$P" "$T_WIRE" \
  "    reason: 'to sync your appearance across devices'," "    reason: 'to see your cart',"
P="$AC/locations/app_locations.dart"
mutate E03 "AppLocations names another location" "$P" "$T_WIRE" \
  "  static const String settingsAppearance = '/settings/appearance';" \
  "  static const String settingsAppearance = '/settings';"
P=app/mini_client/lib/src/router/app_routes.dart
mutate E04 "home's Settings opens the store" "$P" "$T_WIRE" \
  "          unawaited(context.push(AppLocations.settingsAppearance))," \
  "          unawaited(context.push(AppLocations.store)),"
P=utility/mc_test_utils/lib/src/test_container.dart
mutate F01 "the test container follows the account by default" "$P" "$T_TU" \
  "  static bool appearanceFollowsAccount = false;" "  static bool appearanceFollowsAccount = true;"
mutate F02 "the test container ignores the package's opt-in" "$P" "$T_FEAT" \
  "    AppearanceDIInitializer(followAccount: appearanceFollowsAccount)," \
  "    const AppearanceDIInitializer(followAccount: false),"

say ""
say "mutations: $n, killed: $killed"
[[ $rc -eq 0 && $n -eq $killed ]] && say "RESULT: PASS" || { say "RESULT: FAIL"; exit 1; }
