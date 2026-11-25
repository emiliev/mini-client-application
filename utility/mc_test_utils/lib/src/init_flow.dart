import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_test_utils/src/session.dart';
import 'package:mc_test_utils/src/test_container.dart';

/// The app shell of a feature test: the DS theme of the session's variant, the
/// session's locale and text scale, and the iOS platform (TD-04).
class McTestApp extends StatelessWidget {
  const McTestApp({required this.session, required this.home, super.key});

  final McTestSession session;
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: McTheme.of(session.themeVariant)
        .copyWith(platform: TargetPlatform.iOS),
    locale: session.locale,
    supportedLocales: [session.locale],
    // Flutter's own strings in every locale, as the app installs them, so a
    // test in `de` sees no "locale not supported" warning (T-0032-AC4).
    // Feature strings come from each flow's own delegates.
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(session.textScale)),
      child: app!,
    ),
    home: home,
  );
}

/// Pumps the feature flow [flow] over the test root container (Tide's
/// `initFlow`). Initialises the container with [externals] (the doubles of
/// things another package owns), pumps [McTestApp] and one frame. It never
/// settles: the step that follows chooses.
Future<void> initFlow(
  WidgetTester tester,
  Widget Function() flow, {
  List<ExternalDouble<Object>> externals = const [],
}) async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session, externals: externals);
  } else if (externals.isNotEmpty) {
    throw StateError(
      'initFlow got externals but the container is already initialised; '
      'call McTestContainer.initialize with them first.',
    );
  }
  await tester.pumpWidget(McTestApp(session: session, home: flow()));
  await tester.pump();
}
