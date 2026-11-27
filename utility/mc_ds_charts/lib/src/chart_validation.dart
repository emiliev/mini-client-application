import 'package:flutter/foundation.dart';

/// How the charts treat data they cannot draw (NaN, infinite or out-of-model
/// values): an [ArgumentError] in debug and profile builds, and in release the
/// bad datum is skipped and reported once per data change.
///
/// The mode and the reporter are injectable so tests can exercise the release
/// path without a release build.
abstract final class McChartValidation {
  /// Forces the release path (`true`) or the debug path (`false`); `null`
  /// follows [kReleaseMode].
  @visibleForTesting
  static bool? releaseModeOverride;

  /// Where release-mode reports go. Defaults to [FlutterError.reportError].
  @visibleForTesting
  static void Function(FlutterErrorDetails details)? reporterOverride;

  static bool get isRelease => releaseModeOverride ?? kReleaseMode;

  /// Restores the defaults (call from `tearDown`).
  @visibleForTesting
  static void reset() {
    releaseModeOverride = null;
    reporterOverride = null;
  }

  static void _report(String message) {
    final details = FlutterErrorDetails(
      exception: ArgumentError(message),
      library: 'mc_ds_charts',
      informationCollector: null,
    );
    (reporterOverride ?? FlutterError.reportError)(details);
  }

  /// Returns [items] without those [isValid] rejects. Debug: throws an
  /// [ArgumentError] naming [chart] and [what] when any is rejected. Release:
  /// reports once and returns the rest.
  static List<T> sanitize<T>(
    List<T> items,
    bool Function(T item) isValid, {
    required String chart,
    required String what,
    String reason = 'NaN or infinite',
  }) {
    final bad = items.where((i) => !isValid(i)).length;
    if (bad == 0) {
      return items;
    }
    final message = '$chart: $bad $what could not be drawn ($reason).';
    if (!isRelease) {
      throw ArgumentError(message);
    }
    _report('$message Skipped.');
    return items.where(isValid).toList(growable: false);
  }

  /// Reports [message] once in release when [ok] is false, and throws in
  /// debug; returns [ok].
  static bool check(bool ok, String message) {
    if (ok) {
      return true;
    }
    if (!isRelease) {
      throw ArgumentError(message);
    }
    _report(message);
    return false;
  }
}
