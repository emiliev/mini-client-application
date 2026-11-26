import 'package:dio/dio.dart';
import 'package:mc_api_auth/src/auth_api.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_session/mc_session.dart';

/// Adds the bearer token and, on a 401, makes one refresh and replays the
/// request once.
///
/// - Signed out, a request carries no `Authorization` header (one the caller
///   set itself is left alone, and its 401 is never refreshed).
/// - A 401 for a request that carried our token starts one refresh. Every
///   other request that gets a 401 while it runs waits for that same refresh.
///   A 401 that arrives after the refresh finished sees a newer token than
///   the one it sent, so it is just replayed.
/// - A replay that gets a 401 again is not refreshed again.
/// - When the server rejects the refresh (a 4xx, a malformed answer or no
///   refresh token), the session is cleared (`SessionChanged(signedOut)`)
///   and the original 401 reaches the caller as [ApiFailure.unauthorized].
///   When the refresh cannot be tried (offline, timeout, 5xx) the session is
///   kept and the caller sees that failure instead.
///
/// Install it after the retry interceptor, so a replayed request passes
/// through every interceptor again.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._reader, this._writer, this._api);

  /// Set on a request once we put the bearer on it.
  static const _applied = 'mc_api_auth.applied';
  static const _replayed = 'mc_api_auth.replayed';
  static const _prefix = 'Bearer ';

  final Dio _dio;
  final SessionReader _reader;
  final SessionWriter _writer;
  final AuthApi _api;

  Future<_Refresh>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[skipAuthKey] != true) {
      final ours = options.extra[_applied] == true;
      final token = _reader.accessToken;
      if (token != null &&
          (ours || !options.headers.containsKey('Authorization'))) {
        options.headers['Authorization'] = '$_prefix$token';
        options.extra[_applied] = true;
      } else if (token == null && ours) {
        // A replay after a sign-out must not carry the old token.
        options.headers.remove('Authorization');
        options.extra[_applied] = false;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[_applied] != true ||
        options.extra[_replayed] == true ||
        !_reader.isSignedIn) {
      return handler.next(err);
    }
    final sent = _bearer(options);
    if (sent != null && sent == _reader.accessToken) {
      final outcome = await (_refreshing ??= _refresh());
      switch (outcome) {
        case _SignedOut():
          return handler.next(err);
        case _Unavailable(:final failure):
          return handler.next(
            DioException(
              requestOptions: options,
              response: err.response,
              type: DioExceptionType.unknown,
              error: failure,
            ),
          );
        case _Refreshed():
          break;
      }
    }
    // Either we just refreshed, or another request already had.
    try {
      handler.resolve(
        await _dio.fetch<Object?>(
          options.copyWith(extra: {...options.extra, _replayed: true}),
        ),
      );
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<_Refresh> _refresh() async {
    try {
      final result = await _api.refresh();
      return await result.fold<Future<_Refresh>>(
        (tokens) async {
          await _writer.updateTokens(tokens);
          return const _Refreshed();
        },
        (failure) async {
          if (failure is ApiOffline ||
              failure is ApiTimeout ||
              failure is ApiServer) {
            return _Unavailable(failure);
          }
          await _writer.signOut();
          return const _SignedOut();
        },
      );
    } finally {
      // The next 401 that still carries a stale token starts a fresh refresh
      // only if the session did not change, so clearing here is safe.
      _refreshing = null;
    }
  }

  static String? _bearer(RequestOptions options) {
    final header = options.headers['Authorization'];
    return header is String && header.startsWith(_prefix)
        ? header.substring(_prefix.length)
        : null;
  }
}

sealed class _Refresh {
  const _Refresh();
}

final class _Refreshed extends _Refresh {
  const _Refreshed();
}

final class _SignedOut extends _Refresh {
  const _SignedOut();
}

final class _Unavailable extends _Refresh {
  const _Unavailable(this.failure);

  final ApiFailure failure;
}
