import 'dart:async';

import 'package:dio/dio.dart';
import 'package:mc_api_auth/src/auth_api.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_session/mc_session.dart';

/// Adds the bearer token and, on a 401, makes one refresh and replays the
/// request once.
///
/// - Signed out, a request carries no `Authorization` header (one the caller
///   set itself is left alone, and its 401 is never refreshed).
/// - A request remembers the session it was sent for (`SessionReader.epoch`).
///   Everything that happens later is done only while that session is still
///   current: a refresh outcome is applied to it alone, and a 401 is replayed
///   only for it. After a sign-out, or a sign-in as someone else, the 401
///   reaches the caller untouched, so a request of user A is never repeated
///   with user B's token. A retry of A's request (by the retry interceptor)
///   after such a change is failed as unauthorized instead of being sent.
/// - A 401 for a request that carried our token starts one refresh. Every
///   other request that gets a 401 while it runs waits for that same refresh.
///   A 401 that arrives after the refresh finished sees a newer token than
///   the one it sent, so it is just replayed.
/// - A replay that gets a 401 again is not refreshed again. Only 401 refreshes
///   (a 403 does not). A body that cannot be sent twice (a `Stream`) is never
///   replayed, so its 401 is not refreshed either; a `FormData` is cloned.
/// - When the server definitely rejects the refresh (`ApiUnauthorized`, a 4xx
///   other than 408 and 429, or a malformed answer), the session is cleared
///   (`SessionChanged(signedOut)`) and the original 401 reaches the caller as
///   [ApiFailure.unauthorized]. Any other failure (offline, timeout, 5xx, 429,
///   an unexpected error such as a dropped socket or a cancel) means "refresh
///   unavailable": the session is kept and the caller sees that failure.
///
/// Install it after the retry interceptor, so a replayed request passes
/// through every interceptor again.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._reader, this._writer, this._api);

  /// Set on a request once we put the bearer on it.
  static const _applied = 'mc_api_auth.applied';
  static const _epoch = 'mc_api_auth.epoch';
  static const _replayed = 'mc_api_auth.replayed';
  static const _prefix = 'Bearer ';

  final Dio _dio;
  final SessionReader _reader;
  final SessionWriter _writer;
  final AuthApi _api;

  _InFlight? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[skipAuthKey] != true) {
      final ours = options.extra[_applied] == true;
      final token = _reader.accessToken;
      if (ours && options.extra[_epoch] != _reader.epoch && token != null) {
        // A retry of a request that was sent for another session.
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: const ApiFailure.unauthorized('The session changed'),
          ),
        );
      }
      if (token != null &&
          (ours || !options.headers.containsKey('Authorization'))) {
        options.headers['Authorization'] = '$_prefix$token';
        options.extra[_applied] = true;
        options.extra[_epoch] = _reader.epoch;
      } else if (token == null && ours) {
        // A retry after a sign-out must not carry the old token.
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
    final epoch = options.extra[_epoch];
    if (err.response?.statusCode != 401 ||
        options.extra[_applied] != true ||
        options.extra[_replayed] == true ||
        options.data is Stream ||
        epoch is! int ||
        epoch != _reader.epoch) {
      return handler.next(err);
    }
    final sent = _bearer(options);
    if (sent != null && sent == _reader.accessToken) {
      final outcome = await _refreshFor(epoch);
      switch (outcome) {
        case _Rejected():
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
      if (epoch != _reader.epoch) {
        // Signed out, or someone else signed in, while we waited.
        return handler.next(err);
      }
    }
    try {
      handler.resolve(
        await _dio.fetch<Object?>(
          options.copyWith(
            // A FormData is single-use: the replay gets its own copy.
            data: options.data is FormData
                ? (options.data as FormData).clone()
                : options.data,
            extra: {...options.extra, _replayed: true},
          ),
        ),
      );
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// The one refresh for session [epoch]: later 401s of that session share it.
  Future<_Refresh> _refreshFor(int epoch) {
    final current = _refreshing;
    if (current != null && current.epoch == epoch) {
      return current.future;
    }
    final flight = _InFlight(epoch, _refresh(epoch));
    _refreshing = flight;
    unawaited(
      flight.future.whenComplete(() {
        if (identical(_refreshing, flight)) {
          _refreshing = null;
        }
      }),
    );
    return flight.future;
  }

  Future<_Refresh> _refresh(int epoch) async {
    final result = await _api.refresh();
    return result.fold<Future<_Refresh>>(
      (tokens) async {
        // Applied only while the session it was made for is current.
        await _writer.updateTokens(tokens, epoch: epoch);
        return const _Refreshed();
      },
      (failure) async {
        if (_rejects(failure)) {
          await _writer.signOut(ifEpoch: epoch);
          return const _Rejected();
        }
        return _Unavailable(failure);
      },
    );
  }

  /// A definite "no" from the server, as opposed to "could not ask".
  static bool _rejects(ApiFailure failure) => switch (failure) {
    ApiUnauthorized() || ApiMalformed() => true,
    ApiClientError(:final status) => status != 408 && status != 429,
    _ => false,
  };

  static String? _bearer(RequestOptions options) {
    final header = options.headers['Authorization'];
    return header is String && header.startsWith(_prefix)
        ? header.substring(_prefix.length)
        : null;
  }
}

final class _InFlight {
  _InFlight(this.epoch, this.future);

  final int epoch;
  final Future<_Refresh> future;
}

sealed class _Refresh {
  const _Refresh();
}

final class _Refreshed extends _Refresh {
  const _Refreshed();
}

final class _Rejected extends _Refresh {
  const _Rejected();
}

final class _Unavailable extends _Refresh {
  const _Unavailable(this.failure);

  final ApiFailure failure;
}
