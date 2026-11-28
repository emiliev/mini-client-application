import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:settings_home/src/domain/model/account_view.dart';

/// Reads who is signed in (`GET v1/me`), as a value, never an exception.
/// The one call the page makes, so it has no retrofit API of its own.
@injectable
class AccountProfileReader {
  const AccountProfileReader(this._dio);

  final Dio _dio;

  /// The profile of the session [epoch]: the request is pinned to it
  /// (T-0050), so it is never sent with another user's bearer; if the
  /// session changed before it left, the answer is [ApiUnauthorized].
  Future<Result<UserProfile, ApiFailure>> read({required int epoch}) =>
      apiCall(() async {
        final response = await _dio.get<Object?>(
          'v1/me',
          options: Options(extra: authPinned(epoch)),
        );
        final data = response.data;
        return UserProfile.fromJson(data is String ? jsonDecode(data) : data);
      });
}
