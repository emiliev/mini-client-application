import 'package:dio/dio.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';

/// `Options.extra` key: the auth interceptor leaves this request alone (no
/// bearer, no refresh on 401). The sign-in, refresh and sign-out calls set it.
const String skipAuthKey = 'mc_api_auth.skip';

/// Who signed in.
final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  /// Throws a [FormatException] when a field is missing or not a string.
  factory AuthUser.fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'email': final String email,
      'displayName': final String name,
    }) {
      return AuthUser(id: id, email: email, displayName: name);
    }
    throw FormatException('Not a user: $json');
  }

  final String id;
  final String email;
  final String displayName;
}

/// The identity endpoints the session needs. Calls bypass the auth
/// interceptor ([skipAuthKey]), because they carry their own credentials.
class AuthApi {
  AuthApi(this._dio, this._reader, this._writer);

  final Dio _dio;
  final SessionReader _reader;
  final SessionWriter _writer;

  /// Signs in and starts the session (`SessionChanged(signedIn)`). A failed
  /// sign-in leaves the session as it was. A failure to save the session is
  /// not reported: the user is signed in for this run.
  Future<Result<AuthUser, ApiFailure>> signIn({
    required String email,
    required String password,
  }) => apiCall(() async {
    final data = await _post('/v1/auth/sign-in', {
      'email': email,
      'password': password,
    });
    final user = AuthUser.fromJson(data['user']);
    await _writer.signIn(userId: user.id, tokens: _tokens(data));
    return user;
  });

  /// Ends the session at once, then tells the server (best effort). The
  /// result is the server call's; the session is cleared either way.
  ///
  /// With [ifEpoch] it does nothing unless that session is still the current
  /// one (a sign-in started by someone who has since left undoes only its
  /// own session, never a newer one).
  Future<Result<void, ApiFailure>> signOut({int? ifEpoch}) async {
    if (ifEpoch != null && ifEpoch != _reader.epoch) {
      return success(null);
    }
    final refresh = _reader.refreshToken;
    await _writer.signOut(ifEpoch: ifEpoch);
    return apiCall(() async {
      await _dio.post<Object?>(
        '/v1/auth/sign-out',
        data: {if (refresh != null) 'refreshToken': refresh},
        options: Options(extra: {skipAuthKey: true}),
      );
    });
  }

  /// Trades the current refresh token for a new pair. It does not touch the
  /// session; the caller decides (see the interceptor). Fails with
  /// [ApiFailure.unauthorized] when there is no refresh token.
  Future<Result<AuthTokens, ApiFailure>> refresh() {
    final token = _reader.refreshToken;
    if (token == null) {
      return Future.value(failure(const ApiFailure.unauthorized('No session')));
    }
    return apiCall(
      () async => _tokens(
        await _post('/v1/auth/refresh', {
          'refreshToken': token,
        }),
      ),
    );
  }

  Future<Map<String, Object?>> _post(String path, Object body) async {
    final response = await _dio.post<Map<String, Object?>>(
      path,
      data: body,
      options: Options(extra: {skipAuthKey: true}),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty response');
    }
    return data;
  }

  AuthTokens _tokens(Map<String, Object?> data) =>
      AuthTokens.fromJson(data) ??
      (throw const FormatException('Response has no tokens'));
}
