// T-0053-AC3: sessions (injected clock and random) and sinks.
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

import 'support.dart';

List<String> sessionStarts(Rig rig) => [
  for (final e in rig.sink.events)
    if (e.name == sessionStartEventName) e.params['reason']! as String,
];

void main() {
  group('T-0053-AC3 a session rotates after 30 minutes in the background', () {
    Future<Rig> backgroundFor(Duration away) async {
      final rig = Rig();
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(away);
      rig.analytics.appForegrounded();
      await settle();
      return rig;
    }

    test('T-0053-AC3 29:59 keeps the session', () async {
      final rig = Rig();
      final before = rig.analytics.sessionId;
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 29, seconds: 59));

      rig.analytics.appForegrounded();
      await settle();

      expect(rig.analytics.sessionId, before);
      expect(sessionStarts(rig), ['cold_start']);
    });

    test('T-0053-AC3 30:00 starts a new session', () async {
      final rig = Rig();
      final before = rig.analytics.sessionId;
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 30));

      rig.analytics.appForegrounded();
      await settle();

      expect(rig.analytics.sessionId, isNot(before));
      expect(sessionStarts(rig), ['cold_start', 'timeout']);
    });

    test('T-0053-AC3 hours away rotates once', () async {
      final rig = await backgroundFor(const Duration(hours: 5));

      expect(sessionStarts(rig), ['cold_start', 'timeout']);
    });

    test('T-0053-AC3 a second backgrounding keeps the first time', () async {
      final rig = Rig();
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 20));
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 10));

      rig.analytics.appForegrounded();
      await settle();

      expect(sessionStarts(rig), ['cold_start', 'timeout']);
    });

    test('T-0053-AC3 coming back resets the timer: a second short absence '
        'does not rotate', () async {
      final rig = Rig();
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 20));
      rig.analytics.appForegrounded();
      rig.now = rig.now.add(const Duration(minutes: 20));
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 20));

      rig.analytics.appForegrounded();
      await settle();

      expect(sessionStarts(rig), ['cold_start']);
    });

    test('T-0053-AC3 foreground without a background does nothing', () async {
      final rig = Rig();
      rig.now = rig.now.add(const Duration(hours: 2));

      rig.analytics.appForegrounded();
      await settle();

      expect(sessionStarts(rig), ['cold_start']);
    });

    test('T-0053-AC3 a clock that went backwards does not rotate', () async {
      final rig = await backgroundFor(const Duration(hours: -2));

      expect(sessionStarts(rig), ['cold_start']);
    });

    test(
      'T-0053-AC3 the lifecycle states map to background and foreground',
      () async {
        final rig = Rig();
        final observer = AnalyticsLifecycleObserver(rig.analytics);
        final first = rig.analytics.sessionId;

        Future<void> away(AppLifecycleState state) async {
          observer.didChangeAppLifecycleState(state);
          rig.now = rig.now.add(const Duration(minutes: 31));
          observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await settle();
        }

        // inactive is not a background.
        observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
        rig.now = rig.now.add(const Duration(minutes: 31));
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(rig.analytics.sessionId, first);

        for (final state in [
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.detached,
        ]) {
          final before = rig.analytics.sessionId;
          await away(state);
          expect(rig.analytics.sessionId, isNot(before), reason: '$state');
        }
      },
    );
  });

  group('T-0053-AC3 cold start, ids and seq', () {
    test('T-0053-AC3 every cold start is a new session', () async {
      final random = Random(5);
      final ids = <String>{};
      for (var i = 0; i < 20; i++) {
        final analytics = Analytics(
          sinks: const [],
          monitoring: Monitoring(const []),
          random: random,
        );
        ids.add(analytics.sessionId);
      }

      expect(ids, hasLength(20));
    });

    test('T-0053-AC3 the id comes from the injected random', () {
      String idFor(int seed) => Analytics(
        sinks: const [],
        monitoring: Monitoring(const []),
        random: Random(seed),
      ).sessionId;

      expect(idFor(3), idFor(3));
      expect(idFor(3), isNot(idFor(4)));
      expect(idFor(3), matches(RegExp(r'^[0-9a-f]{32}$')));
      final r = Random(3);
      final expected = [
        for (var i = 0; i < 4; i++)
          r.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
      ].join();
      expect(idFor(3), expected);
    });

    test('T-0053-AC3 seq starts at 1 and has no gaps', () async {
      final rig = Rig();

      for (var i = 0; i < 10; i++) {
        rig.analytics.track(AnalyticsEvent('e$i'));
        if (i.isEven) {
          await settle();
        }
      }
      await settle();

      expect(rig.sink.records.map((r) => r.seq), [
        for (var i = 1; i <= 11; i++) i,
      ]);
      expect(rig.sink.records.map((r) => r.sessionId).toSet(), hasLength(1));
    });

    test('T-0053-AC3 seq restarts at 1 in a new session', () async {
      final rig = Rig();
      rig.analytics.track(const AnalyticsEvent('a'));
      await settle();
      final first = rig.analytics.sessionId;
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 30));
      rig.analytics.appForegrounded();
      rig.analytics.track(const AnalyticsEvent('b'));
      await settle();

      expect(
        [for (final r in rig.sink.records) (r.sessionId == first, r.seq)],
        [(true, 1), (true, 2), (false, 1), (false, 2)],
      );
    });

    test(
      'T-0053-AC3 the kit emits mc_session_start first, with its reason',
      () async {
        final rig = Rig();
        await settle();

        final start = rig.sink.events.single;
        expect(start.name, sessionStartEventName);
        expect(start.params, {'reason': 'cold_start'});
        expect(start.seq, 1);
        expect(start.sessionId, rig.analytics.sessionId);
      },
    );

    test(
      'T-0053-AC3 reset starts a new session and drops what waited',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);
        final before = rig.analytics.sessionId;
        rig.analytics.track(const AnalyticsEvent('old'));

        rig.analytics.reset();
        await rig.analytics.setConsent(AnalyticsConsent.granted);
        await settle();

        expect(rig.analytics.sessionId, isNot(before));
        expect(rig.names, isEmpty);
        expect(sessionStarts(rig), ['reset']);
        expect(rig.sink.records.single.seq, 1);
      },
    );

    test('T-0053-AC3 reset after delivery: the next entries are in the new '
        'session from 1', () async {
      final rig = Rig();
      rig.analytics.track(const AnalyticsEvent('old'));
      await settle();
      final before = rig.analytics.sessionId;

      rig.analytics.reset();
      rig.analytics.track(const AnalyticsEvent('new'));
      await settle();

      final after = rig.sink.records.where((r) => r.sessionId != before);
      expect(after.map((r) => r.seq), [1, 2]);
      expect(rig.names, ['old', 'new']);
    });
  });

  group('T-0053-AC3 sinks', () {
    test(
      'T-0053-AC3 a sink that throws does not stop the other sinks',
      () async {
        final bad = ThrowingSink();
        final rig = Rig(extraSinks: [bad]);
        final after = InMemoryAnalyticsSink();
        rig.analytics.addSink(after);

        rig.analytics.track(const AnalyticsEvent('a'));
        rig.analytics.track(const AnalyticsEvent('b'));
        await settle();

        expect(rig.names, ['a', 'b']);
        expect(after.events.map((e) => e.name), [
          sessionStartEventName,
          'a',
          'b',
        ]);
        expect(
          bad.calls,
          greaterThanOrEqualTo(2),
          reason: 'it keeps being called',
        );
      },
    );

    test('T-0053-AC3 a sink listed after a throwing one still gets every '
        'entry', () async {
      final late = InMemoryAnalyticsSink();
      final rig = Rig(extraSinks: [ThrowingSink(), late]);

      rig.analytics.track(const AnalyticsEvent('a'));
      await settle();

      expect(late.events.map((e) => e.name), [sessionStartEventName, 'a']);
    });

    test(
      'T-0053-AC3 a throwing sink is reported once, not per entry',
      () async {
        final rig = Rig(extraSinks: [ThrowingSink()]);

        for (var i = 0; i < 5; i++) {
          rig.analytics.track(AnalyticsEvent('e$i'));
        }
        await settle();

        expect(rig.errors, hasLength(1));
        expect(rig.errors.single.error, isA<StateError>());
        expect(rig.errors.single.stackTrace, isNotNull);
      },
    );

    test('T-0053-AC3 each throwing sink is reported once', () async {
      final rig = Rig(extraSinks: [ThrowingSink(), ThrowingSink()]);

      rig.analytics.track(const AnalyticsEvent('a'));
      rig.analytics.track(const AnalyticsEvent('b'));
      await settle();

      expect(rig.errors, hasLength(2));
    });

    test('T-0053-AC3 a removed sink gets nothing more', () async {
      final rig = Rig();
      final extra = InMemoryAnalyticsSink();
      rig.analytics.addSink(extra);
      rig.analytics.track(const AnalyticsEvent('a'));
      await settle();

      rig.analytics.removeSink(extra);
      rig.analytics.track(const AnalyticsEvent('b'));
      await settle();

      expect(extra.events.map((e) => e.name), [sessionStartEventName, 'a']);
    });

    test('T-0053-AC3 an added sink is still behind the gate', () async {
      final rig = Rig(consent: AnalyticsConsent.denied);
      final extra = InMemoryAnalyticsSink();
      rig.analytics.addSink(extra);

      rig.analytics.track(const AnalyticsEvent('a'));
      await settle();

      expect(extra.records, isEmpty);
    });

    test(
      'T-0053-AC3 the in-memory sink keeps order, screens and clears',
      () async {
        final rig = Rig();
        rig.analytics
          ..screen('home')
          ..track(const AnalyticsEvent('a'))
          ..screen('characters_list');
        await settle();

        expect(rig.sink.screens, ['home', 'characters_list']);
        expect(rig.sink.events.map((e) => e.name), [
          sessionStartEventName,
          screenViewEventName,
          'a',
          screenViewEventName,
        ]);
        expect(
          () => rig.sink.records.add(rig.sink.records.first),
          throwsUnsupportedError,
        );

        rig.sink.clear();
        expect(rig.sink.records, isEmpty);
      },
    );

    test(
      'T-0053-AC3 MonitoringAnalyticsSink forwards events as EventEntry',
      () async {
        final rig = Rig(forwardToMonitoring: true);
        final session = rig.analytics.sessionId;

        rig.analytics.track(
          const AnalyticsEvent('comic_opened', params: {'id': 7, 'title': 'x'}),
        );
        rig.analytics.screen('home');
        await settle();

        final events = rig.monitoringEvents;
        expect(events.map((e) => e.name), [
          sessionStartEventName,
          'comic_opened',
          screenViewEventName,
        ]);
        expect(events[1].attributes, {
          'id': 7,
          'title': 'x',
          'session_id': session,
          'seq': 2,
        });
        expect(events[2].attributes, {
          'screen_name': 'home',
          'session_id': session,
          'seq': 3,
        });
      },
    );

    test(
      'T-0053-AC3 MonitoringAnalyticsSink forwards user properties',
      () async {
        final rig = Rig(forwardToMonitoring: true);

        rig.analytics.setUserProperty('plan', 'free');
        await settle();

        final event = rig.monitoringEvents.last;
        expect(event.name, 'user_property');
        expect(event.attributes['key'], 'plan');
        expect(event.attributes['value'], 'free');
        expect(event.attributes['seq'], 2);
      },
    );
  });
}
