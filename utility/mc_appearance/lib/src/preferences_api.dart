import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_appearance/src/appearance_preferences.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// The account's copy of the preferences and its version
/// (`mc_fixtures_identity` CONTRACT.md, `/v1/me/preferences`).
final class PreferencesCopy {
  const PreferencesCopy(this.preferences, this.version);

  final AppearancePreferences preferences;
  final int version;

  /// The copy in a wire object, or a [FormatException] (an [ApiMalformed]
  /// for the caller) when it is not one.
  static PreferencesCopy parse(Object? json) {
    final decoded = json is String ? jsonDecode(json) : json;
    final preferences = AppearancePreferences.fromWire(decoded);
    final version = decoded is Map ? decoded['version'] : null;
    if (preferences == null || version is! int) {
      throw FormatException('Not a preferences object: $json');
    }
    return PreferencesCopy(preferences, version);
  }
}

/// How a `PATCH` ended.
sealed class PatchOutcome {
  const PatchOutcome();
}

/// `200`: the account now holds [copy].
final class PatchSaved extends PatchOutcome {
  const PatchSaved(this.copy);

  final PreferencesCopy copy;
}

/// `409 version_conflict`: the account is at [current], and nothing was
/// written.
final class PatchConflict extends PatchOutcome {
  const PatchConflict(this.current);

  final PreferencesCopy current;
}

/// Anything else: the request failed (a pinned request for a session that
/// is gone is an [ApiUnauthorized] that never left the device, T-0050).
final class PatchFailed extends PatchOutcome {
  const PatchFailed(this.failure);

  final ApiFailure failure;
}

/// `GET` and `PATCH /v1/me/preferences` over the shared `Dio`, which adds
/// the bearer. Paths are relative (T-0034).
final class PreferencesApi {
  const PreferencesApi(this._dio);

  static const String path = 'v1/me/preferences';

  final Dio _dio;

  /// The account's copy. A read needs no pin: its answer is dropped by the
  /// caller's epoch check when the session changed (F-0050 §2).
  Future<Result<PreferencesCopy, ApiFailure>> read() => apiCall(
    () async => PreferencesCopy.parse((await _dio.get<Object?>(path)).data),
  );

  /// Writes [settings] of [values] if the account is still at [ifVersion],
  /// pinned to [epoch] from the first send (`authPinned`, T-0050).
  Future<PatchOutcome> write({
    required int epoch,
    required int ifVersion,
    required AppearancePreferences values,
    required Set<AppearanceSetting> settings,
  }) async {
    final result = await apiCall(() async {
      final response = await _dio.patch<Object?>(
        path,
        data: {'ifVersion': ifVersion, ...values.toWire(settings)},
        options: Options(
          extra: authPinned(epoch),
          // A 409 is an answer, not an error: its body holds `current`.
          validateStatus: (status) =>
              status != null &&
              (status == 409 || status >= 200 && status < 300),
        ),
      );
      if (response.statusCode == 409) {
        final body = response.data is String
            ? jsonDecode(response.data! as String)
            : response.data;
        final error = body is Map ? body['error'] : null;
        return PatchConflict(
          PreferencesCopy.parse(error is Map ? error['current'] : null),
        );
      }
      return PatchSaved(PreferencesCopy.parse(response.data));
    });
    return result.fold<PatchOutcome>((outcome) => outcome, PatchFailed.new);
  }
}
