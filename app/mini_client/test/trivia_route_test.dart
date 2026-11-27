// T-0064: trivia_quiz inside the real app (the full root list, every wiring
// and the app's mock domains): the Trivia entry on home, the cold link to a
// round with its back stack, and a comic opened from the results.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _home = Key('home.placeholder');
const _setupBody = ValueKey<String>('trivia_setup.body');
const _prompt = ValueKey<String>('trivia_play.prompt');
const _next = ValueKey<String>('trivia_play.next');
const _quit = ValueKey<String>('trivia_play.quit');
const _resultsBody = ValueKey<String>('trivia_results.body');
const _comicTitle = ValueKey<String>('comics_details.title');

void main() {
  late Directory storage;
  late InMemorySink monitoringSink;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('trivia_route_test');
    monitoringSink = InMemorySink();
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester, {String? coldStartLink}) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    if (coldStartLink != null) {
      links.offer(coldStartLink);
    }
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: McFixtureAssetBundle(),
        child: MiniClientApp(
          links: links,
          initializers: (routerRef) => rootInitializers(
            config: () async => _config,
            storageDirectory: storage,
            monitoringSinks: [monitoringSink],
            mockDomains: appMockDomains,
            routerRef: routerRef,
            wirings: wiringInitializers,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  /// Lets a round's load land and the page settle into a question without
  /// waiting for the countdown (it keeps drawing frames).
  Future<void> land(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
  }

  /// Answers every question with its first choice and moves on.
  Future<void> playThrough(WidgetTester tester) async {
    for (var q = 0; q < 10; q++) {
      final choice = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'trivia_play.choice.',
            ),
      );
      await tester.tap(choice.first);
      await tester.pump();
      await tester.ensureVisible(find.byKey(_next));
      await tester.tap(find.byKey(_next));
      await land(tester);
    }
    await tester.pumpAndSettle();
  }

  testWidgets("T-0064-AC5 home's Trivia entry opens the setup, whose "
      'categories come from the app mock domains, and Back goes home', (
    tester,
  ) async {
    await boot(tester);
    await tester.scrollUntilVisible(
      find.text('Trivia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Trivia'));
    await tester.pumpAndSettle();

    expect(router(tester).state.uri.toString(), AppLocations.trivia);
    expect(find.byKey(_setupBody), findsOneWidget);
    for (final name in ['All categories', 'Characters', 'Comics', 'Creators']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('T-0064-AC5 the cold link to a round plays it over the setup '
      'over home; quitting goes to the setup, and Back goes home', (
    tester,
  ) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42',
    );
    await land(tester);

    expect(find.byKey(_prompt), findsOneWidget);
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(find.byKey(_home), findsNothing);
    expect(
      router(tester).state.uri.toString(),
      AppLocations.triviaPlay(
        category: 'characters',
        difficulty: 'easy',
        seed: 42,
      ),
    );

    await tester.tap(find.byKey(_quit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(mcConfirmButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_setupBody), findsOneWidget);
    // go_router keeps the popped child's query on the parent's location.
    expect(router(tester).state.uri.path, AppLocations.trivia);

    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('T-0064-AC3 a comic of the results opens its page, and Back '
      'returns to the results', (tester) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app/trivia/play?category=comics&difficulty=easy&seed=42',
    );
    await land(tester);
    await playThrough(tester);
    expect(find.byKey(_resultsBody), findsOneWidget);

    final comic = find.text('About this comic').first;
    await tester.scrollUntilVisible(
      comic,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(_resultsBody),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(comic);
    await tester.pumpAndSettle();
    expect(find.byKey(_comicTitle), findsOneWidget);
    expect(router(tester).state.uri.toString(), startsWith('/comics/'));

    await back(tester);
    expect(find.byKey(_resultsBody), findsOneWidget);
    // Results, then the setup under the linked round, then home.
    await back(tester);
    expect(find.byKey(_setupBody), findsOneWidget);
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });

  /// The cold link to a round, loaded and on its first question.
  Future<void> openLinkedRound(WidgetTester tester) async {
    await boot(
      tester,
      coldStartLink:
          'miniclient://app/trivia/play?category=all&difficulty=easy&seed=42',
    );
    await land(tester);
    expect(find.byKey(_prompt), findsOneWidget);
  }

  List<MonitoringEntry> errors() => [
    for (final e in monitoringSink.entries)
      if (e is ErrorEntry) e,
  ];

  testWidgets('T-0064-AC3 a link that replaces the round while the quit '
      'dialog is open fails nothing (review round)', (tester) async {
    await openLinkedRound(tester);
    await tester.tap(find.byKey(_quit));
    await tester.pumpAndSettle();
    expect(find.text('Quit this round?'), findsOneWidget);

    router(tester).go(AppLocations.home);
    await tester.pumpAndSettle();

    expect(find.byKey(_home), findsOneWidget);
    expect(find.text('Quit this round?'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(errors(), isEmpty, reason: 'nothing reported to monitoring');
  });

  testWidgets('T-0064-AC3 a system back on a linked round asks to quit and '
      'leaves nothing behind it (review round)', (tester) async {
    await openLinkedRound(tester);
    final location = router(tester).state.uri.toString();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Quit this round?'), findsOneWidget);
    expect(router(tester).state.uri.toString(), location);
    await tester.tap(find.byKey(mcCancelButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_prompt), findsOneWidget, reason: 'the round goes on');
    expect(router(tester).state.uri.toString(), location);
  });

  testWidgets('T-0064-AC3 the iOS back swipe does not pop a round in play '
      '(review round)', (tester) async {
    // The swipe exists only on iOS pages (the test default is Android).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await openLinkedRound(tester);
      final location = router(tester).state.uri.toString();

      // A drag from the left edge, as the Cupertino back gesture expects.
      final gesture = await tester.startGesture(const Offset(2, 400));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(35, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(_prompt), findsOneWidget);
      expect(router(tester).state.uri.toString(), location);
      expect(find.byKey(_setupBody), findsNothing);
    } finally {
      // Reset inside the body: the binding checks before tear-downs run.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
