#!/bin/bash
# T-0061 engineer mutation checks: each mutation of the identity package's
# preferences code must turn at least one test red. A mutant that survives, or
# that does not build, fails this script (a build break is "broken", never
# "killed": only a `FAILED in` test line counts as killed).
#
#   MC_TASK=T-0061 MC_ROLE=engineer documents/evidence/T-0061/engineer/mutations.sh
#
# Refuses to run on a dirty package: every mutation is undone with
# `git checkout -- <package>`, which would also discard uncommitted edits.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
: "${MC_TASK:?set MC_TASK, e.g. T-0061}"
: "${MC_ROLE:?set MC_ROLE, e.g. engineer}"
P=utility/mc_fixtures_identity
P2=utility/mc_mocked_backend # the engine hook (review round)
if [[ -n "$(git status --porcelain "$P" "$P2")" ]]; then
  echo "refusing to run: $P or $P2 has uncommitted changes" >&2
  exit 2
fi
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
PH=$P/lib/src/handlers/preferences_handlers.dart
DOM=$P/lib/src/domain.dart
US=$P/lib/src/data/users.dart
ENG=$P2/lib/src/backend.dart
LOG="$(mktemp -t "mc-$MC_TASK-$MC_ROLE-mut.XXXXXX")"
# The restore trap is set before the first edit.
trap 'git checkout -- "$P" "$P2"; rm -f "$LOG"' EXIT
killed=0
survived=0
broken=0

run_tests() {
  tool/bazelw --output_base="$OB" test //$P/... //$P2/... > "$LOG" 2>&1
}

# mutate <name> <file> <old> <new>
mutate() {
  local name="$1" file="$2" old="$3" new="$4"
  echo "=== $name"
  if ! python3 -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if s.count(old) < 1:
    sys.exit("pattern not found: " + old)
open(p, "w").write(s.replace(old, new, 1))
' "$file" "$old" "$new"; then
    echo "    PATTERN NOT FOUND"; broken=$((broken + 1)); git checkout -- "$P" "$P2"; return
  fi
  # The build checks formatting, so a mutation is formatted like the source.
  fvm dart format "$file" > /dev/null 2>&1
  run_tests
  local failed
  failed="$(tr '\r' '\n' < "$LOG" | grep -aE '^//.*FAILED in' | sed 's/ *FAILED in.*//' | tr '\n' ' ')"
  if tr '\r' '\n' < "$LOG" | grep -aq 'Build did NOT complete'; then
    echo "    BUILD ERROR (does not count as killed)"
    tr '\r' '\n' < "$LOG" | grep -aE 'error|info -|warning' | head -3
    broken=$((broken + 1))
  elif [[ -n "$failed" ]]; then
    echo "    KILLED by: $failed"
    killed=$((killed + 1))
  else
    echo "    SURVIVED"; survived=$((survived + 1))
  fi
  git checkout -- "$P" "$P2"
}

# Baseline: the unmutated tree must pass.
run_tests || { echo "BASELINE FAILS"; tr '\r' '\n' < "$LOG" | tail -20; exit 1; }
echo "baseline PASS"

# --- defaults and seeds ---------------------------------------------------
mutate "D1 the default theme is light" $US "this.seededThemeMode = 'system'," "this.seededThemeMode = 'light',"
mutate "D2 u-101 is seeded light" $US "seededThemeMode: 'dark'," "seededThemeMode: 'light',"
mutate "D3 u-101 is not seeded" $US "seededThemeMode: 'dark'," ""
mutate "D4 u-100 is seeded dark too" $US "seededFavourites: ['character/100000', 'character/100001']," "seededFavourites: ['character/100000', 'character/100001'], seededThemeMode: 'dark',"
mutate "D5 the default density is compact" $PH "String density = 'comfortable';" "String density = 'compact';"
mutate "D6 reduceMotion defaults to true" $PH 'bool reduceMotion = false;' 'bool reduceMotion = true;'
mutate "D7 version starts at 1" $PH 'int version = 0;' 'int version = 1;'
# --- version and updatedAt --------------------------------------------------
mutate "V1 a write adds 2 to the version" $PH 'preferences.version++;' 'preferences.version += 2;'
mutate "V2 a write leaves the version" $PH 'preferences.version++;' 'preferences.version += 0;'
mutate "V3 updatedAt adds 2 s per write" $PH '.add(Duration(seconds: version))' '.add(Duration(seconds: version * 2))'
mutate "V4 updatedAt adds a minute per write" $PH '.add(Duration(seconds: version))' '.add(Duration(minutes: version))'
mutate "V5 updatedAt has no zone" $PH ".toIso8601String(),
    'version': version," ".toIso8601String().substring(0, 23),
    'version': version,"
mutate "V6 a newer ifVersion is accepted" $PH "if (body['ifVersion'] != preferences.version) {" "if ((body['ifVersion'] as int) < preferences.version) {"
mutate "V7 an older ifVersion is accepted" $PH "if (body['ifVersion'] != preferences.version) {" "if ((body['ifVersion'] as int) > preferences.version) {"
mutate "V8 the version is never checked" $PH "if (body['ifVersion'] != preferences.version) {" "if (body['ifVersion'] != preferences.version && preferences.version < 0) {"
mutate "V9 the 409 has no current object" $PH "extra: {'current': preferences.toJson(context.clock)}," "extra: const {},"
mutate "V10 the conflict answers 400" $PH "409,
        'version_conflict'," "400,
        'version_conflict',"
mutate "V11 the conflict code is renamed" $PH "'version_conflict'," "'version_mismatch',"
mutate "V12 a conflict bumps the version" $PH "if (body['ifVersion'] != preferences.version) {
        return conflict();" "if (body['ifVersion'] != preferences.version) {
        preferences.version++;
        return conflict();"
mutate "V13 the 409 message differs" $PH "'The preferences are at version" "'The preferences is at version"
# --- partial apply -----------------------------------------------------------
mutate "A1 themeMode is not applied" $PH "preferences.themeMode = body['themeMode'] as String;" "preferences.themeMode = 'system';"
mutate "A2 density is not applied" $PH "preferences.density = body['density'] as String;" "preferences.density = 'comfortable';"
mutate "A3 reduceMotion is not applied" $PH "preferences.reduceMotion = body['reduceMotion'] as bool;" 'preferences.reduceMotion = false;'
mutate "A4 a density patch also writes the theme" $PH "if (body.containsKey('themeMode')) {
        preferences.themeMode" "if (body.containsKey('themeMode') || body.containsKey('density')) {
        preferences.themeMode"
mutate "A5 the response shows the old version" $PH "preferences.version++;
      return MockResponse.ok(preferences.toJson(context.clock));" "final before = preferences.toJson(context.clock);
      preferences.version++;
      return MockResponse.ok(before);"
mutate "A6 the JSON never shows reduceMotion true" $PH "'reduceMotion': reduceMotion," "'reduceMotion': false,"
mutate "A7 the density key is renamed" $PH "'density': density," "'dense': density,"
# --- values and codes ------------------------------------------------------------
mutate "C1 any string is a theme" $PH "!themeModes.contains(body['themeMode'])) {" "body['themeMode'] is! String) {"
mutate "C2 'auto' is a theme" $PH "const Set<String> themeModes = {'system', 'light', 'dark'};" "const Set<String> themeModes = {'system', 'light', 'dark', 'auto'};"
mutate "C3 'system' is not a theme" $PH "const Set<String> themeModes = {'system', 'light', 'dark'};" "const Set<String> themeModes = {'light', 'dark'};"
mutate "C4 'dark' is not a theme" $PH "const Set<String> themeModes = {'system', 'light', 'dark'};" "const Set<String> themeModes = {'system', 'light'};"
mutate "C5 'tight' is a density" $PH "const Set<String> densities = {'comfortable', 'compact'};" "const Set<String> densities = {'comfortable', 'compact', 'tight'};"
mutate "C6 'compact' is not a density" $PH "const Set<String> densities = {'comfortable', 'compact'};" "const Set<String> densities = {'comfortable'};"
mutate "C7 reduceMotion only rejects null" $PH "body['reduceMotion'] is! bool) {" "body['reduceMotion'] == null) {"
mutate "C8 invalid_theme_mode renamed" $PH "'invalid_theme_mode'," "'invalid_theme',"
mutate "C9 invalid_density renamed" $PH "'invalid_density'," "'invalid_dense',"
mutate "C10 invalid_reduce_motion renamed" $PH "'invalid_reduce_motion'," "'invalid_motion',"
mutate "C11 unknown_key renamed" $PH "'unknown_key'," "'unknown_preference',"
mutate "C12 empty_patch renamed" $PH "'empty_patch'," "'empty',"
mutate "C13 invalid_body renamed" $PH "'invalid_body'," "'bad_body',"
mutate "C14 validation answers 422" $PH "}) => MockResponse.error(400, code, message, extra: extra);" "}) => MockResponse.error(422, code, message, extra: extra);"
mutate "C15 the theme error names no parameter" $PH "extra: {'parameter': 'themeMode'}," 'extra: const {},'
mutate "C16 the unknown key is not named" $PH "extra: {'parameter': '\$key'}," "extra: {'parameter': 'unknown'},"
mutate "C17 the body error names the wrong parameter" $PH "extra: {'parameter': 'ifVersion'}," "extra: {'parameter': 'body'},"
mutate "C18 version is an accepted key" $PH "if (key != 'ifVersion' && !preferenceKeys.contains(key)) {" "if (key != 'ifVersion' && key != 'version' && !preferenceKeys.contains(key)) {"
mutate "C19 a double ifVersion is accepted" $PH "body['ifVersion'] is! int) {" "body['ifVersion'] is! num) {"
mutate "C20 an empty patch needs every key" $PH 'if (!preferenceKeys.any(body.containsKey)) {' 'if (!preferenceKeys.every(body.containsKey)) {'
mutate "C21 an empty patch is accepted" $PH 'if (!preferenceKeys.any(body.containsKey)) {' 'if (!preferenceKeys.any(body.containsKey) && body.length > 5) {'
# --- check order -----------------------------------------------------------------
mutate "O1 the version is checked before unknown keys" $PH "      for (final key in body.keys) {" "      if (body['ifVersion'] != _preferences(context, user).version) {
        return MockResponse.error(409, 'version_conflict', 'x');
      }
      for (final key in body.keys) {"
mutate "O2 an empty patch is checked before unknown keys" $PH "      for (final key in body.keys) {" "      if (!preferenceKeys.any(body.containsKey)) {
        return _invalid('empty_patch', 'x');
      }
      for (final key in body.keys) {"
mutate "O3 density is checked before the theme" $PH "      if (body.containsKey('themeMode') &&
          !themeModes.contains(body['themeMode'])) {" "      if (body.containsKey('density') && !densities.contains(body['density'])) {
        return _invalid('invalid_density', 'x');
      }
      if (body.containsKey('themeMode') &&
          !themeModes.contains(body['themeMode'])) {"
mutate "O4 reduceMotion is checked before density" $PH "      if (body.containsKey('density') && !densities.contains(body['density'])) {" "      if (body.containsKey('reduceMotion') && body['reduceMotion'] is! bool) {
        return _invalid('invalid_reduce_motion', 'x');
      }
      if (body.containsKey('density') && !densities.contains(body['density'])) {"
mutate "O5 a stale version beats a malformed body" $PH "      if (body is! Map || body['ifVersion'] is! int) {" "      if (body is Map && body['ifVersion'] is int && body['ifVersion'] != _preferences(context, user).version) {
        return MockResponse.error(409, 'version_conflict', 'x');
      }
      if (body is! Map || body['ifVersion'] is! int) {"
mutate "O6 the body is checked before the bearer" $PH "      if (user == null) {
        return _unauthenticated();
      }
      final body = request.body;" "      if (user == null) {
        if (request.body is! Map) {
          return _invalid('invalid_body', 'x');
        }
        return _unauthenticated();
      }
      final body = request.body;"
# --- auth and ownership ----------------------------------------------------------
mutate "U1 GET without a bearer reads the reader" $PH "  final user = userForAuthorization(request.headers['authorization']);" "  final user = userForAuthorization(request.headers['authorization'] ?? 'Bearer \${mintAccessToken('u-100', 1)}');"
mutate "U2 PATCH without a bearer writes the reader" $PH "      final user = userForAuthorization(request.headers['authorization']);" "      final user = userForAuthorization(request.headers['authorization'] ?? 'Bearer \${mintAccessToken('u-100', 1)}');"
mutate "U3 unauthenticated answers 403" $PH "MockResponse _unauthenticated() => MockResponse.error(
  401," "MockResponse _unauthenticated() => MockResponse.error(
  403,"
mutate "U4 every user shares one preferences object" $PH "String _key(String userId) => 'identity.preferences.\$userId';" "String _key(String userId) => 'identity.preferences';"
mutate "U5 users share by the first three characters of the id" $PH "String _key(String userId) => 'identity.preferences.\$userId';" "String _key(String userId) => 'identity.preferences.\${userId.substring(0, 3)}';"
mutate "U6 preferences outlive reset" $PH "    (context.store[_key(user.id)] ??= _Preferences(user.seededThemeMode))
        as _Preferences;" "    _kept.putIfAbsent(_key(user.id), () => _Preferences(user.seededThemeMode));

final Map<String, _Preferences> _kept = {};"
# --- routes and scenarios ----------------------------------------------------------
mutate "S1 PATCH is registered as PUT" $DOM "..add('PATCH', '/v1/me/preferences', patchPreferences());" "..add('PUT', '/v1/me/preferences', patchPreferences());"
mutate "S2 the manifest drops the PATCH route" $DOM "    'PATCH /v1/me/preferences',
  ];

  /// The routes" "  ];

  /// The routes"
mutate "S3 preferences_error also fails the other routes" $DOM "for (final route in preferencesRoutes)" "for (final route in routeManifest)"
mutate "S4 preferences_error fails only GET" $DOM "static const List<String> preferencesRoutes = [
    'GET /v1/me/preferences',
    'PATCH /v1/me/preferences',
  ];" "static const List<String> preferencesRoutes = [
    'GET /v1/me/preferences',
  ];"
mutate "S5 preferences_error answers 503" $DOM "for (final route in preferencesRoutes)
                FailureRule(
                  route.split(' ').first,
                  route.split(' ').last,
                  const FailureKind.http(500)," "for (final route in preferencesRoutes)
                FailureRule(
                  route.split(' ').first,
                  route.split(' ').last,
                  const FailureKind.http(503),"
mutate "S6 the conflict fires every time" $PH "if (conflictOnce && context.store[_conflictFiredKey] != true) {" "if (conflictOnce) {"
mutate "S7 the conflict is used up by a rejected request" $PH "      final body = request.body;
      if (body is! Map ||" "      final body = request.body;
      if (conflictOnce && context.store[_conflictFiredKey] != true) {
        context.store[_conflictFiredKey] = true;
        return MockResponse.error(409, 'version_conflict', 'x');
      }
      if (body is! Map ||"
mutate "S8 the conflict writes before it answers" $PH "        context.store[_conflictFiredKey] = true;
        return MockResponse.error(" "        context.store[_conflictFiredKey] = true;
        preferences.version++;
        return MockResponse.error("
mutate "S9 the conflict scenario overrides the wrong route" $DOM "'PATCH /v1/me/preferences': patchPreferences(conflictOnce: true)," "'PATCH /v1/me/preference': patchPreferences(conflictOnce: true),"
mutate "S10 the conflict is never marked fired" $PH "        context.store[_conflictFiredKey] = true;
        return MockResponse.error(" "        return MockResponse.error("
# --- review round: re-arming on selection ------------------------------------
mutate "R1 the conflict scenario is not wired to the hook" $DOM "onSelect: armPreferencesConflict," ""
mutate "R2 the engine never calls onSelect" $ENG "_scenario?.onSelect?.call(_store);" "_scenario?.onSelect;"
mutate "R3 arming clears the wrong key" $PH "store.remove(_conflictFiredKey);" "store.remove('identity.preferencesConflict');"
mutate "R4 arming sets the marker instead of clearing it" $PH "store.remove(_conflictFiredKey);" "store[_conflictFiredKey] = true;"
mutate "R5 the injected 409 reads like a real mismatch" $PH "'Injected version conflict (scenario identity.preferences_conflict)'," "'The preferences are at version \${preferences.version}, not \${body['ifVersion']}',"
mutate "R6 the engine runs onSelect before the scenario is chosen" $ENG "    _scenario = name == null ? null : _scenarios[name];
    _scenario?.onSelect?.call(_store);" "    _scenario?.onSelect?.call(_store);
    _scenario = name == null ? null : _scenarios[name];"

echo
echo "killed=$killed survived=$survived broken=$broken"
[[ $survived -eq 0 && $broken -eq 0 ]]
