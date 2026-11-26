import 'package:mc_fixtures_identity/src/data/users.dart';

/// `mc-access-<userId>-<n>`: valid for a known user and a numeric `n`.
/// `mc-access-<userId>-expired` is the one expired form.
String mintAccessToken(String userId, int n) => 'mc-access-$userId-$n';

String expiredAccessToken(String userId) => 'mc-access-$userId-expired';

/// `mc-refresh-<userId>-<n>`: valid until it is used once (rotation) or
/// signed out.
String mintRefreshToken(String userId, int n) => 'mc-refresh-$userId-$n';

final RegExp _access = RegExp(r'^mc-access-(u-\d+)-(\d+)$');
final RegExp _refresh = RegExp(r'^mc-refresh-(u-\d+)-(\d+)$');

FixtureUser? userById(String id) {
  for (final user in fixtureUsers) {
    if (user.id == id) {
      return user;
    }
  }
  return null;
}

/// The user a bearer `Authorization` header names, or null for a missing,
/// malformed or expired token.
FixtureUser? userForAuthorization(String? header) {
  const prefix = 'Bearer ';
  if (header == null || !header.startsWith(prefix)) {
    return null;
  }
  final match = _access.firstMatch(header.substring(prefix.length));
  return match == null ? null : userById(match.group(1)!);
}

/// The user a well-formed refresh token names, or null.
FixtureUser? userForRefreshToken(String? token) {
  final match = token == null ? null : _refresh.firstMatch(token);
  return match == null ? null : userById(match.group(1)!);
}
