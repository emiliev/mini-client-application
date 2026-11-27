// T-0053-AC4: each analytics step passes when it should and goes red when it
// should (negative controls), over the test container's real `Analytics`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

Future<Analytics> _boot() async {
  await McTestContainer.initialize(McTestSession.current);
  return diContainer<Analytics>();
}

/// The step must fail its expectation (a negative control).
Future<void> _red(Future<void> step) async {
  try {
    await step;
  } on TestFailure {
    return;
  }
  fail('the step passed, but it should have failed');
}

void main() {
  mcTestWidgets('T-0053-AC4 the analytics event {name} was tracked', (
    tester,
  ) async {
    final analytics = await _boot();
    await noAnalyticsEventWasTracked(tester);

    analytics.track(const AnalyticsEvent('comic_opened'));

    await theAnalyticsEventWasTracked(tester, 'comic_opened');
    // Negative controls: another name, a name that was never tracked.
    await _red(theAnalyticsEventWasTracked(tester, 'comic_closed'));
    await _red(theAnalyticsEventWasTracked(tester, 'comic_open'));
  });

  mcTestWidgets('T-0053-AC4 the analytics event {name} was tracked with a '
      'table of params', (tester) async {
    final analytics = await _boot();
    analytics.track(
      const AnalyticsEvent(
        'comic_opened',
        params: {'id': 501500, 'title': 'Spider', 'new': true, 'rating': 4.5},
      ),
    );
    const all = DataTable([
      ['key', 'json'],
      ['id', '501500'],
      ['title', '"Spider"'],
      ['new', 'true'],
      ['rating', '4.5'],
    ]);

    await theAnalyticsEventWasTrackedWith(tester, 'comic_opened', all);

    // Negative controls: a different value, a missing key, an extra key, a
    // different type, a different event name, an empty table.
    await _red(
      theAnalyticsEventWasTrackedWith(
        tester,
        'comic_opened',
        const DataTable([
          ['key', 'json'],
          ['id', '501501'],
          ['title', '"Spider"'],
          ['new', 'true'],
          ['rating', '4.5'],
        ]),
      ),
    );
    await _red(
      theAnalyticsEventWasTrackedWith(
        tester,
        'comic_opened',
        const DataTable([
          ['key', 'json'],
          ['id', '501500'],
        ]),
      ),
    );
    await _red(
      theAnalyticsEventWasTrackedWith(
        tester,
        'comic_opened',
        const DataTable([
          ['key', 'json'],
          ['id', '501500'],
          ['title', '"Spider"'],
          ['new', 'true'],
          ['rating', '4.5'],
          ['extra', '1'],
        ]),
      ),
    );
    await _red(
      theAnalyticsEventWasTrackedWith(
        tester,
        'comic_opened',
        const DataTable([
          ['key', 'json'],
          ['id', '"501500"'],
          ['title', '"Spider"'],
          ['new', 'true'],
          ['rating', '4.5'],
        ]),
      ),
    );
    await _red(theAnalyticsEventWasTrackedWith(tester, 'comic_closed', all));
    await _red(
      theAnalyticsEventWasTrackedWith(
        tester,
        'comic_opened',
        const DataTable([
          ['key', 'json'],
        ]),
      ),
    );
  });

  mcTestWidgets('T-0053-AC4 no analytics event was tracked', (tester) async {
    final analytics = await _boot();

    // The kit's session start and a screen view are not feature events.
    analytics.screen('home');
    await noAnalyticsEventWasTracked(tester);

    // Negative control: a feature event turns it red.
    analytics.track(const AnalyticsEvent('comic_opened'));
    await _red(noAnalyticsEventWasTracked(tester));
  });

  mcTestWidgets('T-0053-AC4 the screen {name} was tracked', (tester) async {
    final analytics = await _boot();
    analytics.screen('characters_list');

    await theScreenWasTracked(tester, 'characters_list');

    // Negative controls: another screen; a feature event is not a screen.
    await _red(theScreenWasTracked(tester, 'home'));
    analytics.track(const AnalyticsEvent('home'));
    await _red(theScreenWasTracked(tester, 'home'));
  });

  mcTestWidgets('T-0053-AC4 the steps see nothing while consent is denied', (
    tester,
  ) async {
    final analytics = await _boot();
    // The save is real file I/O, which fake async cannot await (F-0038); the
    // choice itself applies at once.
    unawaited(analytics.setConsent(AnalyticsConsent.denied));

    analytics.track(const AnalyticsEvent('comic_opened'));
    analytics.screen('home');

    await _red(theAnalyticsEventWasTracked(tester, 'comic_opened'));
    await _red(theScreenWasTracked(tester, 'home'));
    await noAnalyticsEventWasTracked(tester);
  });
}
