// T-0053-AC1: the consent gate (P1-05 AC4). Nothing reaches a sink unless
// consent is granted when the entry is delivered.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_storage/mc_storage.dart';

import 'support.dart';

void trackOneOfEach(Analytics analytics) {
  analytics
    ..track(const AnalyticsEvent('comic_opened', params: {'id': 7}))
    ..screen('home')
    ..setUserProperty('plan', 'free');
}

void main() {
  group('T-0053-AC1 nothing reaches a sink without consent', () {
    test(
      'T-0053-AC1 unknown: track, screen and user property deliver 0',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);

        trackOneOfEach(rig.analytics);
        await settle();

        expect(rig.sink.records, isEmpty);
        // Buffered, not lost: session start + the three.
        expect(rig.analytics.bufferedCount, 4);
      },
    );

    test(
      'T-0053-AC1 denied: track, screen and user property deliver 0',
      () async {
        final rig = Rig(consent: AnalyticsConsent.denied);

        trackOneOfEach(rig.analytics);
        await settle();

        expect(rig.sink.records, isEmpty);
        expect(
          rig.analytics.bufferedCount,
          0,
          reason: 'denied buffers nothing',
        );
      },
    );

    test('T-0053-AC1 the monitoring sink gets nothing either', () async {
      final unknown = Rig(
        consent: AnalyticsConsent.unknown,
        forwardToMonitoring: true,
      );
      final denied = Rig(
        consent: AnalyticsConsent.denied,
        forwardToMonitoring: true,
      );

      trackOneOfEach(unknown.analytics);
      trackOneOfEach(denied.analytics);
      await settle();

      expect(unknown.monitoringSink.entries, isEmpty);
      expect(denied.monitoringSink.entries, isEmpty);
    });

    test('T-0053-AC1 granted delivers, one microtask later', () async {
      final rig = Rig();

      rig.analytics.track(const AnalyticsEvent('comic_opened'));
      expect(rig.sink.records, isEmpty, reason: 'never inline');
      await settle();

      expect(rig.names, ['comic_opened']);
    });
  });

  group('T-0053-AC1 unknown to granted flushes in order', () {
    test('T-0053-AC1 order, session and seq are kept', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      final session = rig.analytics.sessionId;
      rig.analytics
        ..track(const AnalyticsEvent('first'))
        ..screen('home')
        ..setUserProperty('plan', 'free')
        ..track(const AnalyticsEvent('last'));

      unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
      await settle();

      final records = rig.sink.records;
      expect(records, hasLength(5));
      expect(records.map((r) => r.seq), [1, 2, 3, 4, 5]);
      expect(records.map((r) => r.sessionId).toSet(), {session});
      expect((records[0] as AnalyticsEventRecord).name, sessionStartEventName);
      expect((records[1] as AnalyticsEventRecord).name, 'first');
      expect(rig.sink.screens, ['home']);
      expect((records[3] as AnalyticsUserPropertyRecord).key, 'plan');
      expect((records[4] as AnalyticsEventRecord).name, 'last');
    });

    test(
      'T-0053-AC1 an entry tracked after the switch follows the buffer',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);
        rig.analytics.track(const AnalyticsEvent('buffered'));

        unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
        rig.analytics.track(const AnalyticsEvent('after'));
        await settle();

        expect(rig.names, ['buffered', 'after']);
        expect(rig.sink.records.map((r) => r.seq), [1, 2, 3]);
      },
    );

    test('T-0053-AC1 a session that rotated while buffered keeps both ids '
        'and counts each from 1', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      final first = rig.analytics.sessionId;
      rig.analytics.track(const AnalyticsEvent('a'));
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(minutes: 31));
      rig.analytics.appForegrounded();
      final second = rig.analytics.sessionId;
      rig.analytics.track(const AnalyticsEvent('b'));

      unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
      await settle();

      expect(first, isNot(second));
      expect(
        [for (final r in rig.sink.records) (r.sessionId == first, r.seq)],
        [(true, 1), (true, 2), (false, 1), (false, 2)],
      );
    });

    test(
      'T-0053-AC1 events flush once: a second grant delivers nothing',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);
        rig.analytics.track(const AnalyticsEvent('a'));
        await rig.analytics.setConsent(AnalyticsConsent.granted);
        await settle();
        final delivered = rig.sink.records.length;

        await rig.analytics.setConsent(AnalyticsConsent.denied);
        await rig.analytics.setConsent(AnalyticsConsent.granted);
        await settle();

        expect(rig.sink.records, hasLength(delivered));
      },
    );
  });

  group('T-0053-AC1 unknown to denied discards', () {
    test('T-0053-AC1 the buffer is discarded and a later grant does not '
        'bring it back', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      trackOneOfEach(rig.analytics);

      await rig.analytics.setConsent(AnalyticsConsent.denied);
      expect(rig.analytics.bufferedCount, 0);
      await rig.analytics.setConsent(AnalyticsConsent.granted);
      await settle();

      expect(rig.sink.records, isEmpty);
    });

    test('T-0053-AC1 denied, then tracked: dropped at once', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      await rig.analytics.setConsent(AnalyticsConsent.denied);

      rig.analytics.track(const AnalyticsEvent('late'));
      await settle();

      expect(rig.analytics.bufferedCount, 0);
      expect(rig.sink.records, isEmpty);
    });
  });

  group('T-0053-AC1 a switch to denied stops delivery at once', () {
    test('T-0053-AC1 an event tracked in the same turn, before the switch, '
        'is not delivered', () async {
      final rig = Rig();
      await settle();
      rig.sink.clear();

      rig.analytics.track(const AnalyticsEvent('same_turn'));
      unawaited(rig.analytics.setConsent(AnalyticsConsent.denied));
      await settle();

      expect(rig.sink.records, isEmpty);
    });

    test('T-0053-AC1 an event tracked in the same turn, after the switch '
        '(the save still pending), is not delivered', () async {
      final rig = Rig();
      await settle();
      rig.sink.clear();

      final saving = rig.analytics.setConsent(AnalyticsConsent.denied);
      rig.analytics.track(const AnalyticsEvent('same_turn'));
      rig.analytics.screen('home');
      rig.analytics.setUserProperty('plan', 'free');
      await saving;
      await settle();

      expect(rig.sink.records, isEmpty);
    });

    test('T-0053-AC1 granted then denied in one turn delivers nothing of the '
        'buffer', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      trackOneOfEach(rig.analytics);

      unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
      unawaited(rig.analytics.setConsent(AnalyticsConsent.denied));
      await settle();

      expect(rig.sink.records, isEmpty);
      expect(rig.analytics.bufferedCount, 0);
    });

    test(
      'T-0053-AC1 entries delivered before the switch stay delivered',
      () async {
        final rig = Rig();
        rig.analytics.track(const AnalyticsEvent('before'));
        await settle();

        unawaited(rig.analytics.setConsent(AnalyticsConsent.denied));
        rig.analytics.track(const AnalyticsEvent('after'));
        await settle();

        expect(rig.names, ['before']);
      },
    );

    test('T-0053-AC1 a sink that denies in the middle of a flush stops the '
        'rest', () async {
      late final Rig rig;
      final denier = HookSink((record) {
        if (record.seq == 2) {
          unawaited(rig.analytics.setConsent(AnalyticsConsent.denied));
        }
      });
      rig = Rig(consent: AnalyticsConsent.unknown, extraSinks: [denier]);
      for (var i = 0; i < 5; i++) {
        rig.analytics.track(AnalyticsEvent('e$i'));
      }

      unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
      await settle();

      expect(denier.records, hasLength(2));
      expect(rig.sink.records, hasLength(2));
      expect(rig.analytics.bufferedCount, 0);
    });

    test('T-0053-AC1 a sink that moves consent back to unknown in the middle '
        'of a flush stops the rest, which stays buffered', () async {
      late final Rig rig;
      final pauser = HookSink((record) {
        if (record.seq == 2) {
          unawaited(rig.analytics.setConsent(AnalyticsConsent.unknown));
        }
      });
      rig = Rig(consent: AnalyticsConsent.unknown, extraSinks: [pauser]);
      for (var i = 0; i < 5; i++) {
        rig.analytics.track(AnalyticsEvent('e$i'));
      }

      unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
      await settle();

      expect(pauser.records, hasLength(2));
      expect(rig.analytics.bufferedCount, 4, reason: '6 entries, 2 delivered');
    });

    test('T-0053-AC1 granted back to unknown holds what was queued', () async {
      final rig = Rig();
      await settle();
      rig.sink.clear();
      rig.analytics.track(const AnalyticsEvent('held'));

      unawaited(rig.analytics.setConsent(AnalyticsConsent.unknown));
      await settle();

      expect(rig.sink.records, isEmpty);
      expect(rig.analytics.bufferedCount, 1);
    });
  });

  group('T-0053-AC1 the buffer holds 100, the oldest dropped', () {
    // The kit's own session start takes the first place.
    test('T-0053-AC1 100 entries fit: nothing dropped', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);

      for (var i = 0; i < 99; i++) {
        rig.analytics.track(AnalyticsEvent('e$i'));
      }
      expect(rig.analytics.bufferedCount, 100);
      expect(rig.analytics.droppedCount, 0);
      expect(rig.monitoringEvents, isEmpty, reason: 'no overflow report');

      unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
      await settle();

      expect(rig.sink.records, hasLength(100));
      expect(rig.sink.events.first.name, sessionStartEventName);
      expect(rig.sink.records.map((r) => r.seq), [
        for (var i = 1; i <= 100; i++) i,
      ]);
    });

    test(
      'T-0053-AC1 the 101st drops the oldest and reports the count',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);

        for (var i = 0; i < 100; i++) {
          rig.analytics.track(AnalyticsEvent('e$i'));
        }
        expect(rig.analytics.bufferedCount, 100);
        expect(rig.analytics.droppedCount, 1);
        expect(rig.monitoringEvents.map((e) => e.name), [
          'analytics_buffer_overflow',
        ]);
        expect(rig.monitoringEvents.single.attributes, {
          'dropped': 1,
          'limit': 100,
        });

        unawaited(rig.analytics.setConsent(AnalyticsConsent.granted));
        await settle();

        // The session start was the oldest; e0 is now first, and seq has no
        // gap although one entry was dropped.
        expect(rig.sink.records, hasLength(100));
        expect(rig.sink.events.first.name, 'e0');
        expect(rig.sink.events.last.name, 'e99');
        expect(rig.sink.records.map((r) => r.seq), [
          for (var i = 1; i <= 100; i++) i,
        ]);
      },
    );

    test(
      'T-0053-AC1 the total dropped is reported when consent is chosen',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);
        for (var i = 0; i < 130; i++) {
          rig.analytics.track(AnalyticsEvent('e$i'));
        }
        expect(rig.analytics.droppedCount, 31);

        await rig.analytics.setConsent(AnalyticsConsent.denied);

        expect(rig.monitoringEvents.map((e) => e.attributes['dropped']), [
          1,
          31,
        ]);
        expect(rig.analytics.bufferedCount, 0);
      },
    );

    test('T-0053-AC1 a later unknown period is reported afresh', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      for (var i = 0; i < 101; i++) {
        rig.analytics.track(AnalyticsEvent('e$i'));
      }
      await rig.analytics.setConsent(AnalyticsConsent.denied);
      rig.monitoringSink.clear();

      await rig.analytics.setConsent(AnalyticsConsent.unknown);
      for (var i = 0; i < 101; i++) {
        rig.analytics.track(AnalyticsEvent('f$i'));
      }

      expect(rig.monitoringEvents.single.attributes['dropped'], 1);
    });

    test(
      'T-0053-AC1 going back to unknown trims what was queued to 100',
      () async {
        final rig = Rig();
        for (var i = 0; i < 120; i++) {
          rig.analytics.track(AnalyticsEvent('e$i'));
        }

        unawaited(rig.analytics.setConsent(AnalyticsConsent.unknown));
        await settle();

        expect(rig.analytics.bufferedCount, 100);
        expect(rig.sink.records, isEmpty);
      },
    );
  });

  group('T-0053-AC1 consent changes and persistence', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mc_analytics_t'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('T-0053-AC1 consentChanges emits each change, not a repeat', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      final seen = <AnalyticsConsent>[];
      final sub = rig.analytics.consentChanges.listen(seen.add);

      await rig.analytics.setConsent(AnalyticsConsent.granted);
      await rig.analytics.setConsent(AnalyticsConsent.granted);
      await rig.analytics.setConsent(AnalyticsConsent.denied);
      await settle();
      await sub.cancel();

      expect(seen, [AnalyticsConsent.granted, AnalyticsConsent.denied]);
    });

    test('T-0053-AC1 the default consent is unknown', () {
      expect(AnalyticsConsent.parse(null), AnalyticsConsent.unknown);
      expect(AnalyticsConsent.parse('granted'), AnalyticsConsent.granted);
      expect(AnalyticsConsent.parse('denied'), AnalyticsConsent.denied);
      expect(AnalyticsConsent.parse('unknown'), AnalyticsConsent.unknown);
      expect(AnalyticsConsent.parse('GRANTED'), AnalyticsConsent.unknown);
      expect(AnalyticsConsent.parse(true), AnalyticsConsent.unknown);
      expect(
        Analytics(
          sinks: const [],
          monitoring: Rig().monitoring,
        ).consent,
        AnalyticsConsent.unknown,
      );
    });

    test('T-0053-AC1 consent persists across restarts', () async {
      final store = ConsentStore(FileStore(dir));
      final first = Rig(
        consent: AnalyticsConsent.unknown,
        persist: store.save,
      );

      await first.analytics.setConsent(AnalyticsConsent.denied);
      // A "restart": a new store and a new Analytics over the same directory.
      final restored = await ConsentStore(FileStore(dir)).restore(
        AnalyticsConsent.granted,
      );

      expect(restored, AnalyticsConsent.denied, reason: 'saved beats default');
      await first.analytics.setConsent(AnalyticsConsent.granted);
      expect(
        await ConsentStore(FileStore(dir)).restore(AnalyticsConsent.denied),
        AnalyticsConsent.granted,
      );
    });

    test(
      'T-0053-AC1 two choices in one turn: the last one is the one saved',
      () async {
        final store = ConsentStore(FileStore(dir));
        final rig = Rig(consent: AnalyticsConsent.unknown, persist: store.save);

        final first = rig.analytics.setConsent(AnalyticsConsent.granted);
        final second = rig.analytics.setConsent(AnalyticsConsent.denied);
        await Future.wait([first, second]);

        expect(
          await ConsentStore(FileStore(dir)).restore(AnalyticsConsent.granted),
          AnalyticsConsent.denied,
        );
      },
    );

    test('T-0053-AC1 nothing saved gives the fallback', () async {
      final store = ConsentStore(FileStore(dir));

      expect(
        await store.restore(AnalyticsConsent.granted),
        AnalyticsConsent.granted,
      );
      expect(
        await store.restore(AnalyticsConsent.unknown),
        AnalyticsConsent.unknown,
      );
    });

    test(
      'T-0053-AC1 a damaged or unrecognised saved value never grants',
      () async {
        final files = FileStore(dir);
        final store = ConsentStore(files);

        File('${dir.path}/${_hex(ConsentStore.defaultKey)}.json')
            .writeAsStringSync('{ not json');
        expect(
          await store.restore(AnalyticsConsent.granted),
          AnalyticsConsent.unknown,
        );

        await files.write(ConsentStore.defaultKey, 'yes please');
        expect(
          await store.restore(AnalyticsConsent.granted),
          AnalyticsConsent.unknown,
        );

        await files.write(ConsentStore.defaultKey, null);
        expect(
          await store.restore(AnalyticsConsent.denied),
          AnalyticsConsent.denied,
          reason: 'a null value is "nothing saved"',
        );
      },
    );

    test(
      'T-0053-AC1 a failed save is reported and the choice still applies',
      () async {
        final rig = Rig(
          consent: AnalyticsConsent.unknown,
          persist: (_) async => throw const StorageFailure('k', 'disk full'),
        );
        rig.analytics.track(const AnalyticsEvent('a'));

        await rig.analytics.setConsent(AnalyticsConsent.denied);

        expect(rig.analytics.consent, AnalyticsConsent.denied);
        expect(rig.analytics.bufferedCount, 0);
        expect(rig.errors, hasLength(1));
        expect(rig.errors.single.error, isA<StorageFailure>());
      },
    );

    test(
      'T-0053-AC1 a save that cannot write throws the storage failure',
      () async {
        final file = File('${dir.path}/not-a-dir')..writeAsStringSync('x');
        final store = ConsentStore(FileStore(Directory(file.path)));

        await expectLater(
          store.save(AnalyticsConsent.granted),
          throwsA(isA<StorageFailure>()),
        );
      },
    );

    test('T-0053-AC1 reset drops what waits and keeps consent', () async {
      final rig = Rig(consent: AnalyticsConsent.unknown);
      trackOneOfEach(rig.analytics);

      rig.analytics.reset();

      // Only the new session's start is left.
      expect(rig.analytics.bufferedCount, 1);
      expect(rig.analytics.consent, AnalyticsConsent.unknown);
    });
  });

  group('T-0053-AC1 reset keeps what was already queued', () {
    test(
      'T-0053-AC1 granted: track then reset in one turn still delivers it',
      () async {
        final rig = Rig();
        final before = rig.analytics.sessionId;

        rig.analytics.track(const AnalyticsEvent('signed_out'));
        rig.analytics.reset();
        await settle();

        final records = rig.sink.records;
        // The old session's start and the event keep their id and seq; the new
        // session starts at 1 after them.
        expect(
          [for (final r in records) (r.sessionId == before, r.seq)],
          [(true, 1), (true, 2), (false, 1)],
        );
        expect(rig.names, ['signed_out']);
        expect(rig.analytics.sessionId, isNot(before));
      },
    );

    test(
      'T-0053-AC1 unknown: the buffer that waits for a choice is dropped',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);
        rig.analytics.track(const AnalyticsEvent('signed_out'));

        rig.analytics.reset();
        await rig.analytics.setConsent(AnalyticsConsent.granted);
        await settle();

        expect(rig.names, isEmpty);
        expect(rig.sink.records, hasLength(1), reason: 'only the new start');
      },
    );

    test(
      'T-0053-AC1 denied: nothing is queued, nothing is delivered',
      () async {
        final rig = Rig(consent: AnalyticsConsent.denied);

        rig.analytics.track(const AnalyticsEvent('signed_out'));
        rig.analytics.reset();
        await settle();

        expect(rig.sink.records, isEmpty);
        expect(rig.analytics.bufferedCount, 0);
      },
    );
  });

  group('T-0053-AC3 a disposed Analytics does nothing', () {
    test('T-0053-AC3 track, screen, user property, reset and consent are '
        'no-ops, and nothing is saved', () async {
      final saved = <AnalyticsConsent>[];
      final rig = Rig(
        consent: AnalyticsConsent.unknown,
        persist: (c) async => saved.add(c),
      );
      rig.analytics.track(const AnalyticsEvent('before'));
      rig.analytics.dispose();
      final session = rig.analytics.sessionId;

      rig.analytics.track(const AnalyticsEvent('after'));
      rig.analytics.screen('home');
      rig.analytics.setUserProperty('plan', 'free');
      rig.analytics.reset();
      rig.analytics.appBackgrounded();
      rig.now = rig.now.add(const Duration(hours: 1));
      rig.analytics.appForegrounded();
      await rig.analytics.setConsent(AnalyticsConsent.granted);
      await settle();

      expect(rig.analytics.consent, AnalyticsConsent.unknown);
      expect(rig.analytics.sessionId, session);
      expect(rig.analytics.bufferedCount, 0);
      expect(rig.sink.records, isEmpty);
      expect(saved, isEmpty);
    });

    test('T-0053-AC3 an invalid entry after dispose does not throw', () {
      final rig = Rig();
      rig.analytics.dispose();

      rig.analytics.track(const AnalyticsEvent('Bad'));
      rig.analytics.screen('Bad Name');
      rig.analytics.setUserProperty('Bad', 1);
    });

    test('T-0053-AC3 queued entries are not delivered after dispose', () async {
      final rig = Rig();
      rig.analytics.track(const AnalyticsEvent('queued'));

      rig.analytics.dispose();
      await settle();

      expect(rig.sink.records, isEmpty);
    });
  });
}

String _hex(String key) =>
    key.codeUnits.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
