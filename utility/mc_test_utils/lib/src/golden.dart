/// Golden-test harness: real fonts, iOS platform, theme x text-scale matrix.
///
/// Test-only (`testonly = True`): production packages must not depend on it.
/// Moved here from `mc_ds_testing` (P-033, T-0026), which re-exports it.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Bazel `data` label every golden-testing package must list.
const String mcFontsDataLabel = '//utility/mc_ds_theme:fonts';

/// The family name the harness registers Inter under. It is the name the
/// app resolves for `McTypeScale` styles (`packages/mc_ds_theme/Inter`).
const String mcRegisteredFontFamily = mcResolvedFontFamily;

const _fontFiles = [
  'Inter-Regular.ttf',
  'Inter-Medium.ttf',
  'Inter-SemiBold.ttf',
  'Inter-Bold.ttf',
];

const _fontsRelDir = 'utility/mc_ds_theme/assets/fonts';

bool _fontsLoaded = false;

/// Directories that may hold the font files, in order of preference:
/// Bazel runfiles (cwd is the runfiles workspace root, `TEST_SRCDIR` is set)
/// then a plain `flutter test` run from a package or the repo root.
List<String> _candidateDirs() => [
  if (Platform.environment['TEST_SRCDIR'] case final src?)
    '$src/${Platform.environment['TEST_WORKSPACE'] ?? '_main'}/$_fontsRelDir',
  _fontsRelDir,
  '../mc_ds_theme/assets/fonts',
  'assets/fonts',
];

/// Where the SDK's MaterialIcons font may be: an explicit override, the
/// Bazel runfiles (any top-level repo dir ending in `flutter_material_fonts`,
/// so the canonical repo name is not hard-coded), or the Flutter SDK.
List<String> _materialIconsCandidates() {
  const file = 'MaterialIcons-Regular.otf';
  final env = Platform.environment;
  final src = env['TEST_SRCDIR'];
  return [
    if (env['MC_MATERIAL_ICONS'] case final override?) override,
    if (src != null && Directory(src).existsSync())
      for (final e in Directory(src).listSync())
        if (e.path.endsWith('flutter_material_fonts'))
          '${e.path}/material-fonts/$file',
    if (env['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts/$file',
  ];
}

/// Registers the bundled Inter family with the engine. Needed because the
/// tester runs with asset fonts disabled and would otherwise draw Ahem boxes
/// (F-0004 gotcha 1).
Future<void> mcLoadFonts() async {
  if (_fontsLoaded) {
    return;
  }
  final dir = _candidateDirs().firstWhere(
    (d) => File('$d/${_fontFiles.first}').existsSync(),
    orElse: () => throw StateError(
      'Inter fonts not found. Tried: ${_candidateDirs()} (cwd ${Directory.current.path}). '
      'Add $mcFontsDataLabel to the test target `data`.',
    ),
  );
  final loader = FontLoader(mcRegisteredFontFamily);
  for (final f in _fontFiles) {
    final bytes = File('$dir/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  // Icons: without this every Icon draws as an empty box.
  final icons = _materialIconsCandidates().where((f) => File(f).existsSync());
  if (icons.isEmpty) {
    throw StateError(
      'MaterialIcons font not found. Tried: ${_materialIconsCandidates()}',
    );
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(File(icons.first).readAsBytesSync())),
    );
  await iconLoader.load();
  _fontsLoaded = true;
}

/// Wraps [child] in a themed, iOS-platform [MaterialApp] at [textScale].
Widget mcGoldenApp({
  required Widget child,
  McThemeVariant variant = McThemeVariant.light,
  double textScale = 1.0,
}) {
  final theme = McTheme.of(variant).copyWith(platform: TargetPlatform.iOS);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        highContrast:
            variant == McThemeVariant.highContrast ||
            variant == McThemeVariant.highContrastDark,
      ),
      child: app!,
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}

/// Sets a [width] x [height] logical surface at 2x and resets it afterwards.
void mcSetSurface(WidgetTester tester, double width, double height) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width * 2, height * 2);
  addTearDown(tester.view.reset);
}

/// Registers one golden test per theme variant x text scale (1.0 and 2.0).
///
/// Test names carry [acId] for ADR-0006 traceability. Goldens are read from
/// `goldens/<component>.<variant>.x<scale>.png` next to the test file, which
/// under Bazel must be listed in `data`.
void mcGoldenMatrix({
  required String acId,
  required String component,
  required Widget Function(BuildContext context) builder,
  double width = 375,
  double height = 480,
  double heightAtScale2 = 800,
  Duration settle = Duration.zero,
}) {
  for (final variant in McThemeVariant.values) {
    for (final scale in const [1.0, 2.0]) {
      final label = 'x${scale.toStringAsFixed(0)}';
      testWidgets('$acId $component golden ${variant.name} $label', (
        tester,
      ) async {
        await mcLoadFonts();
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          mcSetSurface(tester, width, scale > 1 ? heightAtScale2 : height);
          await tester.pumpWidget(
            mcGoldenApp(
              variant: variant,
              textScale: scale,
              child: Builder(builder: builder),
            ),
          );
          await tester.pump();
          // A fixed fake-clock advance gives animations a deterministic frame.
          if (settle > Duration.zero) {
            await tester.pump(settle);
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$component.${variant.name}.$label.png'),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
