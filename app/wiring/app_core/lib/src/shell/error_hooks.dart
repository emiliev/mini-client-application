import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Resolves [Monitoring] if boot has registered it yet, else null.
Monitoring? rootMonitoring() =>
    diContainer.isRegistered<Monitoring>() ? diContainer<Monitoring>() : null;

/// Installs the Flutter error hooks that forward to [Monitoring] (D-11:
/// `mc_monitoring` is pure Dart, so the hooks live here). Call it in
/// `main()` before `runApp`, never in a widget test (the test binding owns
/// `FlutterError.onError`).
///
/// - Framework errors are still presented (console, red screen in debug) and
///   recorded as non-fatal.
/// - Uncaught asynchronous errors are recorded as fatal and marked handled.
///
/// Errors before boot registers `Monitoring` are only presented. Returns a
/// function that restores the previous hooks.
VoidCallback installErrorHooks({
  Monitoring? Function() monitoring = rootMonitoring,
}) {
  final previousFlutter = FlutterError.onError;
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final previousPlatform = dispatcher.onError;
  FlutterError.onError = flutterErrorHook(monitoring);
  dispatcher.onError = platformErrorHook(monitoring);
  return () {
    FlutterError.onError = previousFlutter;
    dispatcher.onError = previousPlatform;
  };
}

/// The `FlutterError.onError` hook: presents, then records non-fatal.
FlutterExceptionHandler flutterErrorHook(Monitoring? Function() monitoring) =>
    (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      monitoring()?.recordError(details.exception, details.stack);
    };

/// The `PlatformDispatcher.onError` hook: records fatal and reports the
/// error handled, or leaves it unhandled before `Monitoring` exists.
ErrorCallback platformErrorHook(Monitoring? Function() monitoring) =>
    (Object error, StackTrace stack) {
      final sink = monitoring();
      if (sink == null) {
        return false;
      }
      sink.recordError(error, stack, fatal: true);
      return true;
    };
