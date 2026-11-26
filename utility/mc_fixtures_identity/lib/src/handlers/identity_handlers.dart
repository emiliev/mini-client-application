import 'package:mc_fixtures_identity/src/data/users.dart';
import 'package:mc_fixtures_identity/src/handlers/tokens.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// Favourite kinds the API accepts.
const Set<String> favouriteKinds = {'character', 'comic', 'event', 'series'};

const int _accessSeconds = 900;

const String _counterKey = 'identity.counter';
const String _revokedKey = 'identity.revokedRefresh';

String _favouritesKey(String userId) => 'identity.favourites.$userId';

/// The next token number. It skips numbers whose refresh token this backend
/// already revoked: a session saved by an earlier run (the backend starts
/// empty on each launch) may hold such a token.
int _nextToken(MockContext context, String userId) {
  var n = context.store[_counterKey] as int? ?? 0;
  do {
    n++;
  } while (_revoked(context).contains(mintRefreshToken(userId, n)));
  context.store[_counterKey] = n;
  return n;
}

Set<String> _revoked(MockContext context) =>
    (context.store[_revokedKey] ??= <String>{}) as Set<String>;

/// The user's favourites as `kind/id`, in the order they were added. The
/// default set seeds them on first use; the store keeps later changes until
/// `reset()`.
List<String> _favourites(
  MockContext context,
  FixtureUser user, {
  required bool seed,
}) =>
    (context.store[_favouritesKey(user.id)] ??= <String>[
          if (seed) ...user.seededFavourites,
        ])
        as List<String>;

MockResponse _unauthenticated() => MockResponse.error(
  401,
  'unauthenticated',
  'A valid bearer token is required',
);

MockResponse _invalidBody(String message) =>
    MockResponse.error(400, 'invalid_body', message);

Map<String, Object?> _tokenBody(String userId, int n, {bool expired = false}) =>
    {
      'accessToken': expired
          ? expiredAccessToken(userId)
          : mintAccessToken(userId, n),
      'refreshToken': mintRefreshToken(userId, n),
      'tokenType': 'Bearer',
      'expiresIn': _accessSeconds,
    };

/// `POST /v1/auth/sign-in` with `{email, password}`. With [expired] the
/// access token it hands out is already expired (the `expired_token`
/// scenario); the refresh token is good.
MockHandler signIn({bool expired = false}) => (request, context) {
  final body = request.body;
  if (body is! Map || body['email'] is! String || body['password'] is! String) {
    return _invalidBody('Expected {"email": string, "password": string}');
  }
  final email = (body['email'] as String).trim().toLowerCase();
  FixtureUser? user;
  for (final candidate in fixtureUsers) {
    if (candidate.email == email) {
      user = candidate;
    }
  }
  if (user == null || user.password != body['password']) {
    return MockResponse.error(
      401,
      'invalid_credentials',
      'Wrong email or password',
    );
  }
  return MockResponse.ok({
    'user': user.toJson(),
    ..._tokenBody(user.id, _nextToken(context, user.id), expired: expired),
  });
};

/// `POST /v1/auth/refresh` with `{refreshToken}`. Refresh tokens rotate: each
/// works once, so two refreshes with one token make the second fail.
MockResponse refresh(MockRequest request, MockContext context) {
  final body = request.body;
  if (body is! Map || body['refreshToken'] is! String) {
    return _invalidBody('Expected {"refreshToken": string}');
  }
  final token = body['refreshToken'] as String;
  final user = userForRefreshToken(token);
  if (user == null || _revoked(context).contains(token)) {
    return MockResponse.error(
      401,
      'invalid_refresh_token',
      'The refresh token is unknown, used or signed out',
    );
  }
  _revoked(context).add(token);
  return MockResponse.ok(_tokenBody(user.id, _nextToken(context, user.id)));
}

/// `POST /v1/auth/sign-out` with an optional `{refreshToken}` to revoke. It
/// needs no bearer, so a client with an expired token can still sign out.
MockResponse signOut(MockRequest request, MockContext context) {
  final body = request.body;
  if (body is Map && body['refreshToken'] is String) {
    _revoked(context).add(body['refreshToken'] as String);
  }
  return const MockResponse(204);
}

/// `GET /v1/me`: the signed-in user and how many favourites they have.
MockHandler me({required bool seed}) => (request, context) {
  final user = userForAuthorization(request.headers['authorization']);
  if (user == null) {
    return _unauthenticated();
  }
  return MockResponse.ok({
    ...user.toJson(),
    'favouriteCount': _favourites(context, user, seed: seed).length,
  });
};

/// `GET`, `PUT` and `DELETE /v1/me/favourites/:kind/:id`. Writes are
/// idempotent and persist in the backend's store until `reset()`.
MockHandler favourite(String method, {required bool seed}) =>
    (request, context) {
      final user = userForAuthorization(request.headers['authorization']);
      if (user == null) {
        return _unauthenticated();
      }
      final kind = context.params['kind']!;
      final id = context.params['id']!;
      if (!favouriteKinds.contains(kind)) {
        return MockResponse.error(
          400,
          'invalid_parameter',
          'kind must be one of ${(favouriteKinds.toList()..sort()).join(', ')}',
          extra: {'parameter': 'kind'},
        );
      }
      final key = '$kind/$id';
      final favourites = _favourites(context, user, seed: seed);
      switch (method) {
        case 'PUT':
          if (!favourites.contains(key)) {
            favourites.add(key);
          }
        case 'DELETE':
          favourites.remove(key);
        default:
          if (!favourites.contains(key)) {
            return MockResponse.error(
              404,
              'not_favourite',
              '$key is not a favourite',
              extra: {'kind': kind, 'id': id},
            );
          }
      }
      return MockResponse.ok({
        'kind': kind,
        'id': id,
        'favourite': favourites.contains(key),
      });
    };
