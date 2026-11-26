// T-0036 Verifier probe (the exemplar): characters_list pushed from a home
// page, the preview open, the locale changes en -> de, the user taps the
// preview's back button; is the list's back button there, and does it go home?
// Not part of the branch: copied into the package with a temporary BUILD
// target, run, removed.
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'feature/util/characters_list_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets('P1 locale change with the preview open keeps the list back '
      'button', (tester) async {
    final session = McTestSession.current;
    session.backend.useFixtureSet('characters.default');
    await McTestContainer.initialize(session);
    final locale = ValueNotifier<Locale>(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, l, _) => MaterialApp(
          theme: McTheme.light.copyWith(platform: TargetPlatform.iOS),
          locale: l,
          supportedLocales: const [Locale('en'), Locale('de')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        charactersTestHost(charactersListFlowUnderTest()),
                  ),
                ),
                child: const Text('home: open characters'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home: open characters'));
    await mcSettle(tester);
    final first = defaultCast.first.name;
    expect(find.text(first), findsOneWidget);
    final listBefore = find.byType(BackButton).evaluate().length;

    await tester.tap(find.text(first));
    await mcSettle(tester);
    expect(find.byKey(characterPreviewTitleKey), findsOneWidget);
    final onPreview = find.byType(BackButton).evaluate().length;

    locale.value = const Locale('de');
    await mcSettle(tester);
    expect(find.text('Figuren', skipOffstage: false), findsOneWidget);

    // The user taps the preview's (automatic) back button.
    await tester.tap(find.byType(BackButton));
    await mcSettle(tester);
    expect(find.byKey(characterPreviewTitleKey), findsNothing);
    expect(find.text('Figuren'), findsOneWidget);
    final listAfter = find.byType(BackButton).evaluate().length;
    print('P1 back buttons: list before=$listBefore preview up=$onPreview '
        'list after locale change + pop=$listAfter');
    expect(listBefore, 1);
    expect(onPreview, 1, reason: 'no duplicate on the preview');
    expect(listAfter, 1, reason: 'the list back button survived');

    await tester.tap(find.byType(BackButton));
    await mcSettle(tester);
    expect(find.text('home: open characters'), findsOneWidget);
    expect(find.text('Figuren'), findsNothing);
    print('P1 one tap on the list back button returned home');
  });
}
