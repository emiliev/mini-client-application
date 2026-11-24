import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/src/backend_harness.dart';
import 'package:mc_test_utils/src/golden.dart';
import 'package:mc_test_utils/src/mocks.dart';

/// The reference surface: iPhone 17 Pro, logical pixels at DPR 1.
const Size mcReferenceSurface = Size(402, 874);

/// Everything one test owns. A new one is made for every [mcTestWidgets] test
/// and nothing survives it, so tests never see each other's state.
final class McTestSession {
  McTestSession._()
    : backend = McBackendHarness(),
      monitoring = createMockMonitoring(),
      storageDirectory = Directory.systemTemp.createTempSync('mc_test_');

  static McTestSession? _current;

  /// The running test's session. Throws outside [mcTestWidgets].
  static McTestSession get current =>
      _current ??
      (throw StateError(
        'No test session: McTestSession is only available inside '
        'mcTestWidgets.',
      ));

  /// True while an [mcTestWidgets] test runs.
  static bool get isActive => _current != null;

  /// The doubled network.
  final McBackendHarness backend;

  final MockMonitoring monitoring;

  /// A temporary directory standing in for the app's storage directory.
  final Directory storageDirectory;

  /// Used by `initFlow`; a test sets them before pumping.
  double textScale = 1.0;
  McThemeVariant themeVariant = McThemeVariant.light;
  Locale locale = const Locale('en');

  /// Set once `McTestContainer.initialize` has run.
  bool containerInitialized = false;

  static Future<McTestSession> _start(WidgetTester tester) async {
    await mcLoadFonts();
    await resetDIContainer();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    return _current = McTestSession._();
  }

  Future<void> _finish(WidgetTester tester) async {
    try {
      // Unmount first, so flows dispose their child containers.
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
      _current = null;
      await resetDIContainer();
      if (storageDirectory.existsSync()) {
        storageDirectory.deleteSync(recursive: true);
      }
    }
  }

  /// Runs [body], then fails on unmatched requests and unreleased holds. When
  /// [body] itself throws after an unmatched request, the failure names the
  /// route (the 404 the app saw is only a symptom).
  Future<void> guard(Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (error) {
      if (backend.unmatched.isNotEmpty) {
        try {
          backend.verify();
        } on TestFailure catch (failure) {
          throw TestFailure('${failure.message}\nThe test body failed: $error');
        }
      }
      rethrow;
    }
    backend.verify();
  }

  static final RegExp _traceTag = RegExp(r'^(T-\d+-AC\d+|MC-[\w-]+)$');

  /// Moves `T-XXXX-ACn` / `MC-...` tags into the test name (KD4); everything
  /// else stays a Dart tag.
  static (String name, List<String> dartTags) splitTags(
    String description,
    List<String>? tags,
  ) {
    final clean = [
      for (final t in tags ?? const <String>[]) t.replaceFirst('@', ''),
    ];
    final trace = clean.where(_traceTag.hasMatch).toList();
    final dart = clean.where((t) => !_traceTag.hasMatch(t)).toList();
    return (
      trace.isEmpty ? description : '$description [${trace.join(' ')}]',
      dart,
    );
  }
}

/// A widget test with a fresh world (Tide's `testWidgets`, hardened).
///
/// Per test it creates a [McTestSession] (strict zero-latency backend, mock
/// monitoring, storage directory), resets the DI container, sets the iOS
/// platform and a 402x874 @1x surface, and loads the bundled fonts. After the
/// body it fails on unmatched requests and unreleased holds, then restores
/// every global, also when the body throws.
void mcTestWidgets(
  String description,
  WidgetTesterCallback body, {
  List<String>? tags,
  Timeout? timeout,
}) {
  final (name, dartTags) = McTestSession.splitTags(description, tags);
  testWidgets(
    name,
    (tester) async {
      final session = await McTestSession._start(tester);
      try {
        await session.guard(() => body(tester));
      } finally {
        await session._finish(tester);
      }
    },
    tags: dartTags.isEmpty ? null : dartTags,
    timeout: timeout,
  );
}

/// How an action step ends (never a bare `pumpAndSettle`): 500 ms fires
/// debounce timers (the repo-wide maximum), then the tree settles. While a
/// hold keeps an indicator spinning, two fixed frames are pumped instead.
Future<void> mcSettle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  if (McTestSession.isActive && McTestSession.current.backend.hasHolds) {
    await tester.pump();
    await tester.pump();
    return;
  }
  await tester.pumpAndSettle();
}
