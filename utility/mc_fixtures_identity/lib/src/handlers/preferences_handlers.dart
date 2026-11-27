import 'package:mc_fixtures_identity/src/data/users.dart';
import 'package:mc_fixtures_identity/src/handlers/tokens.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The values `themeMode` accepts.
const Set<String> themeModes = {'system', 'light', 'dark'};

/// The values `density` accepts.
const Set<String> densities = {'comfortable', 'compact'};

/// The preference keys of the API, in the order their values are validated.
const List<String> preferenceKeys = ['themeMode', 'density', 'reduceMotion'];

String _key(String userId) => 'identity.preferences.$userId';

const String _conflictFiredKey = 'identity.preferencesConflictFired';

/// Arms `identity.preferences_conflict`: each selection of the scenario
/// clears its fired marker.
void armPreferencesConflict(Map<String, Object?> store) =>
    store.remove(_conflictFiredKey);

/// What the store keeps for one user. A user who never saved has none: the
/// defaults (and the seeded `themeMode`) are built on first use.
final class _Preferences {
  _Preferences(this.themeMode);

  String themeMode;
  String density = 'comfortable';
  bool reduceMotion = false;
  int version = 0;

  /// `updatedAt` is the fixed clock plus one second per write, so version 0
  /// is the clock itself.
  Map<String, Object?> toJson(DateTime clock) => {
    'themeMode': themeMode,
    'density': density,
    'reduceMotion': reduceMotion,
    'updatedAt': clock
        .add(Duration(seconds: version))
        .toUtc()
        .toIso8601String(),
    'version': version,
  };
}

_Preferences _preferences(MockContext context, FixtureUser user) =>
    (context.store[_key(user.id)] ??= _Preferences(user.seededThemeMode))
        as _Preferences;

MockResponse _unauthenticated() => MockResponse.error(
  401,
  'unauthenticated',
  'A valid bearer token is required',
);

MockResponse _invalid(
  String code,
  String message, {
  Map<String, Object?> extra = const {},
}) => MockResponse.error(400, code, message, extra: extra);

/// `GET /v1/me/preferences`: the signed-in user's preferences.
MockResponse getPreferences(MockRequest request, MockContext context) {
  final user = userForAuthorization(request.headers['authorization']);
  if (user == null) {
    return _unauthenticated();
  }
  return MockResponse.ok(_preferences(context, user).toJson(context.clock));
}

/// `PATCH /v1/me/preferences` with the keys to change and `ifVersion`.
///
/// The checks run in a fixed order, and the first failure answers: bearer
/// (401), body shape and `ifVersion` (400 `invalid_body`), unknown keys
/// (`unknown_key`), no preference key (`empty_patch`), the values in the
/// order of [preferenceKeys], then the version (409 `version_conflict`). A
/// rejected request changes nothing.
///
/// With [conflictOnce] the first request that gets as far as the version
/// check answers 409 without writing (the `identity.preferences_conflict`
/// scenario); later requests are served normally.
MockHandler patchPreferences({bool conflictOnce = false}) =>
    (request, context) {
      final user = userForAuthorization(request.headers['authorization']);
      if (user == null) {
        return _unauthenticated();
      }
      final body = request.body;
      if (body is! Map || body['ifVersion'] is! int) {
        return _invalid(
          'invalid_body',
          'Expected an object with an integer "ifVersion" and the '
              'preferences to change',
          extra: {'parameter': 'ifVersion'},
        );
      }
      for (final key in body.keys) {
        if (key != 'ifVersion' && !preferenceKeys.contains(key)) {
          return _invalid(
            'unknown_key',
            'Unknown preference "$key"',
            extra: {'parameter': '$key'},
          );
        }
      }
      if (!preferenceKeys.any(body.containsKey)) {
        return _invalid(
          'empty_patch',
          'Give at least one of ${preferenceKeys.join(', ')}',
        );
      }
      if (body.containsKey('themeMode') &&
          !themeModes.contains(body['themeMode'])) {
        return _invalid(
          'invalid_theme_mode',
          'themeMode must be one of ${themeModes.join(', ')}',
          extra: {'parameter': 'themeMode'},
        );
      }
      if (body.containsKey('density') && !densities.contains(body['density'])) {
        return _invalid(
          'invalid_density',
          'density must be one of ${densities.join(', ')}',
          extra: {'parameter': 'density'},
        );
      }
      if (body.containsKey('reduceMotion') && body['reduceMotion'] is! bool) {
        return _invalid(
          'invalid_reduce_motion',
          'reduceMotion must be true or false',
          extra: {'parameter': 'reduceMotion'},
        );
      }
      final preferences = _preferences(context, user);
      MockResponse conflict() => MockResponse.error(
        409,
        'version_conflict',
        'The preferences are at version ${preferences.version}, not '
            '${body['ifVersion']}',
        extra: {'current': preferences.toJson(context.clock)},
      );
      if (conflictOnce && context.store[_conflictFiredKey] != true) {
        context.store[_conflictFiredKey] = true;
        return MockResponse.error(
          409,
          'version_conflict',
          'Injected version conflict (scenario identity.preferences_conflict)',
          extra: {'current': preferences.toJson(context.clock)},
        );
      }
      if (body['ifVersion'] != preferences.version) {
        return conflict();
      }
      if (body.containsKey('themeMode')) {
        preferences.themeMode = body['themeMode'] as String;
      }
      if (body.containsKey('density')) {
        preferences.density = body['density'] as String;
      }
      if (body.containsKey('reduceMotion')) {
        preferences.reduceMotion = body['reduceMotion'] as bool;
      }
      preferences.version++;
      return MockResponse.ok(preferences.toJson(context.clock));
    };
