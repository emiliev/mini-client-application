// T-0053-AC2: every validation rule and boundary. Debug builds throw; the
// release path (an injected mode flag, not a release build) drops the event
// and reports it to monitoring exactly once.
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_analytics/mc_analytics.dart';

import 'support.dart';

String _name(int length) => 'a' * length;

void main() {
  group('T-0053-AC2 names', () {
    test('T-0053-AC2 1 and 40 characters are valid, 41 is not', () {
      expect(AnalyticsRules.validateName(_name(1)), isEmpty);
      expect(AnalyticsRules.validateName(_name(40)), isEmpty);
      expect(
        AnalyticsRules.validateName(_name(41)).map((v) => v.kind),
        [AnalyticsViolationKind.nameTooLong],
      );
    });

    test('T-0053-AC2 the empty name is not valid', () {
      expect(
        AnalyticsRules.validateName('').map((v) => v.kind),
        [AnalyticsViolationKind.badName],
      );
    });

    test('T-0053-AC2 only snake_case passes', () {
      for (final good in ['a', 'comic_opened', 'a1', 'a_1_b', 'x9']) {
        expect(AnalyticsRules.validateName(good), isEmpty, reason: good);
        expect(AnalyticsRules.isValidName(good), isTrue, reason: good);
      }
      for (final bad in [
        'Comic',
        'comicOpened',
        'comic-opened',
        'comic opened',
        '1comic',
        '_comic',
        'comic_',
        'comic__opened',
        'comic.opened',
        'cömic',
        '/search',
        '/',
      ]) {
        expect(
          AnalyticsRules.validateName(bad).map((v) => v.kind),
          contains(AnalyticsViolationKind.badName),
          reason: bad,
        );
        expect(AnalyticsRules.isValidName(bad), isFalse, reason: bad);
      }
    });

    test(
      'T-0053-AC2 every reserved prefix is rejected, the kit may use them',
      () {
        for (final prefix in AnalyticsRules.reservedPrefixes) {
          final name = '${prefix}thing';
          expect(
            AnalyticsRules.validateName(name).map((v) => v.kind),
            [AnalyticsViolationKind.reservedName],
            reason: name,
          );
          expect(
            AnalyticsRules.validateName(name, allowReserved: true),
            isEmpty,
          );
        }
        expect(AnalyticsRules.reservedPrefixes, contains('mc_'));
        // A name that merely contains a prefix is fine.
        expect(AnalyticsRules.validateName('my_mc_thing'), isEmpty);
        expect(AnalyticsRules.validateName('mc'), isEmpty);
      },
    );
  });

  group('T-0053-AC2 params', () {
    Map<String, Object> params(int n) => {
      for (var i = 0; i < n; i++) 'p$i': i,
    };

    test('T-0053-AC2 25 params are valid, 26 are not', () {
      expect(AnalyticsRules.validateEvent('e', params(25)), isEmpty);
      expect(
        AnalyticsRules.validateEvent('e', params(26)).map((v) => v.kind),
        [AnalyticsViolationKind.tooManyParams],
      );
      expect(AnalyticsRules.validateEvent('e', const {}), isEmpty);
    });

    test(
      'T-0053-AC2 param keys follow the name rules, 40 characters at most',
      () {
        expect(AnalyticsRules.validateEvent('e', {_name(40): 1}), isEmpty);
        expect(
          AnalyticsRules.validateEvent('e', {_name(41): 1}).map((v) => v.kind),
          [AnalyticsViolationKind.paramKeyTooLong],
        );
        expect(
          AnalyticsRules.validateEvent('e', {'Bad Key': 1}).map((v) => v.kind),
          [AnalyticsViolationKind.badParamKey],
        );
        expect(
          AnalyticsRules.validateEvent('e', {'': 1}).map((v) => v.kind),
          [AnalyticsViolationKind.badParamKey],
        );
      },
    );

    test('T-0053-AC2 the keys the kit adds cannot be passed', () {
      for (final key in AnalyticsRules.reservedParamKeys) {
        expect(
          AnalyticsRules.validateEvent('e', {key: 1}).map((v) => v.kind),
          [AnalyticsViolationKind.reservedParamKey],
          reason: key,
        );
      }
      expect(
        AnalyticsRules.validateEvent('e', {'seq': 1}, allowReserved: true),
        isEmpty,
        reason: 'the kit passes its own',
      );
    });

    test('T-0053-AC2 String, int, double and bool values are valid', () {
      expect(
        AnalyticsRules.validateEvent('e', {
          's': 'text',
          'i': 3,
          'd': 1.5,
          'b': false,
        }),
        isEmpty,
      );
    });

    test('T-0053-AC2 a string is 100 characters at most, counted as '
        'characters', () {
      expect(
        AnalyticsRules.validateEvent('e', {'s': 'x' * 100}),
        isEmpty,
      );
      expect(
        AnalyticsRules.validateEvent('e', {'s': 'x' * 101}).map((v) => v.kind),
        [AnalyticsViolationKind.stringTooLong],
      );
      // 100 emoji are 200 UTF-16 units but 100 characters.
      expect(
        AnalyticsRules.validateEvent('e', {'s': '\u{1F980}' * 100}),
        isEmpty,
      );
      expect(
        AnalyticsRules.validateEvent('e', {'s': '\u{1F980}' * 101}),
        isNotEmpty,
      );
      expect(AnalyticsRules.validateEvent('e', {'s': ''}), isEmpty);
    });

    test('T-0053-AC2 NaN and infinity are rejected', () {
      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          AnalyticsRules.validateEvent('e', {'d': value}).map((v) => v.kind),
          [AnalyticsViolationKind.nonFiniteNumber],
          reason: '$value',
        );
      }
      expect(AnalyticsRules.validateEvent('e', {'d': -0.0}), isEmpty);
    });

    test('T-0053-AC2 any other value type is rejected', () {
      for (final value in <Object>[
        [1, 2],
        {'a': 1},
        DateTime(2026),
        const Duration(seconds: 1),
        Object(),
      ]) {
        expect(
          AnalyticsRules.validateEvent('e', {'v': value}).map((v) => v.kind),
          [AnalyticsViolationKind.unsupportedValueType],
          reason: '${value.runtimeType}',
        );
      }
    });

    test('T-0053-AC2 every broken rule is listed, not only the first', () {
      final kinds = AnalyticsRules.validateEvent('Bad', {
        'Worse': 1.0 / 0,
        'seq': 1,
      }).map((v) => v.kind);

      expect(
        kinds,
        containsAll([
          AnalyticsViolationKind.badName,
          AnalyticsViolationKind.badParamKey,
          AnalyticsViolationKind.nonFiniteNumber,
          AnalyticsViolationKind.reservedParamKey,
        ]),
      );
    });
  });

  group('T-0053-AC2 debug mode throws an AssertionError', () {
    test('T-0053-AC2 track', () {
      final rig = Rig();

      expect(
        () => rig.analytics.track(const AnalyticsEvent('Bad Name')),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => rig.analytics.track(const AnalyticsEvent('mc_custom')),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => rig.analytics.track(
          AnalyticsEvent('ok', params: {'p': 'x' * 101}),
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'message',
            contains('101 characters'),
          ),
        ),
      );
    });

    test('T-0053-AC2 screen', () {
      final rig = Rig();

      expect(
        () => rig.analytics.screen('Home Page'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => rig.analytics.screen('home', params: {'screen_name': 'x'}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('T-0053-AC2 setUserProperty', () {
      final rig = Rig();

      expect(
        () => rig.analytics.setUserProperty('Bad Key', 'x'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => rig.analytics.setUserProperty('mc_plan', 'x'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => rig.analytics.setUserProperty('plan', 'x' * 101),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => rig.analytics.setUserProperty('plan', [1]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('T-0053-AC2 an invalid entry throws even while consent is denied', () {
      final rig = Rig(consent: AnalyticsConsent.denied);

      expect(
        () => rig.analytics.track(const AnalyticsEvent('Bad')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('T-0053-AC2 nothing is delivered for the rejected entry', () async {
      final rig = Rig();
      try {
        rig.analytics.track(const AnalyticsEvent('Bad'));
      } on AssertionError {
        // expected
      }
      await settle();

      expect(rig.names, isEmpty);
    });
  });

  group('T-0053-AC2 release mode drops and reports once', () {
    test(
      'T-0053-AC2 an invalid event is dropped and reported exactly once',
      () async {
        final rig = Rig(debugMode: false);

        rig.analytics.track(const AnalyticsEvent('Bad Name'));
        await settle();

        expect(rig.names, isEmpty);
        expect(rig.errors, hasLength(1));
        expect(rig.errors.single.fatal, isFalse);
        final error = rig.errors.single.error as AnalyticsValidationError;
        expect(error.what, 'event "Bad Name"');
        expect(error.violations.single.kind, AnalyticsViolationKind.badName);
      },
    );

    test('T-0053-AC2 one report per invalid entry, however many rules it '
        'breaks', () async {
      final rig = Rig(debugMode: false);

      rig.analytics.track(
        AnalyticsEvent('Bad Name', params: {'Worse': 1, 'p': 'x' * 101}),
      );
      await settle();

      expect(rig.errors, hasLength(1));
      expect(
        (rig.errors.single.error as AnalyticsValidationError).violations,
        hasLength(3),
      );
    });

    test(
      'T-0053-AC2 screen and user property are dropped and reported too',
      () async {
        final rig = Rig(debugMode: false);

        rig.analytics.screen('Bad Screen');
        rig.analytics.setUserProperty('Bad Key', 'x');
        await settle();

        expect(rig.sink.screens, isEmpty);
        expect(
          rig.sink.records.whereType<AnalyticsUserPropertyRecord>(),
          isEmpty,
        );
        expect(rig.errors, hasLength(2));
      },
    );

    test('T-0053-AC2 a valid event after an invalid one is delivered, with '
        'no gap in seq', () async {
      final rig = Rig(debugMode: false);

      rig.analytics.track(const AnalyticsEvent('Bad'));
      rig.analytics.track(const AnalyticsEvent('good'));
      await settle();

      expect(rig.names, ['good']);
      expect(rig.sink.records.map((r) => r.seq), [1, 2]);
      expect(rig.errors, hasLength(1));
    });

    test('T-0053-AC2 the debug default follows the build mode', () {
      // flutter_test runs in debug mode: the default throws.
      final analytics = Analytics(
        sinks: const [],
        monitoring: Rig().monitoring,
      );

      expect(
        () => analytics.track(const AnalyticsEvent('Bad')),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('T-0053-AC2 messages', () {
    test('T-0053-AC2 a rejected entry says what is wrong', () {
      const error = AnalyticsValidationError('event "Bad"', [
        AnalyticsViolation(AnalyticsViolationKind.badName, 'name is bad'),
        AnalyticsViolation(AnalyticsViolationKind.tooManyParams, '26 params'),
      ]);

      expect(
        error.toString(),
        'AnalyticsValidationError: invalid event "Bad" dropped: '
        'name is bad; 26 params',
      );
      expect(
        const AnalyticsEvent('a', params: {'p': 1}).toString(),
        'AnalyticsEvent(a, {p: 1})',
      );
      expect(
        const AnalyticsEventRecord(
          name: 'a',
          params: {'p': 1},
          sessionId: 's',
          seq: 2,
        ).toString(),
        'AnalyticsEventRecord(s #2 a {p: 1})',
      );
      expect(
        const AnalyticsUserPropertyRecord(
          key: 'k',
          value: 'v',
          sessionId: 's',
          seq: 3,
        ).toString(),
        'AnalyticsUserPropertyRecord(s #3 k=v)',
      );
    });
  });

  group('T-0053-AC2 what is accepted', () {
    test('T-0053-AC2 a valid event keeps its typed params', () async {
      final rig = Rig();

      rig.analytics.track(
        const AnalyticsEvent(
          'comic_opened',
          params: {'id': 501500, 'title': 'Spider', 'rating': 4.5, 'new': true},
        ),
      );
      await settle();

      final event = rig.sink.events.last;
      expect(event.name, 'comic_opened');
      expect(event.params, {
        'id': 501500,
        'title': 'Spider',
        'rating': 4.5,
        'new': true,
      });
    });

    test(
      'T-0053-AC2 later edits to the caller\'s map do not reach the sink',
      () async {
        final rig = Rig(consent: AnalyticsConsent.unknown);
        final params = <String, Object>{'id': 1};

        rig.analytics.track(AnalyticsEvent('a', params: params));
        params['id'] = 2;
        params['extra'] = 3;
        await rig.analytics.setConsent(AnalyticsConsent.granted);
        await settle();

        expect(rig.sink.events.last.params, {'id': 1});
        expect(
          () => rig.sink.events.last.params['x'] = 1,
          throwsUnsupportedError,
        );
      },
    );

    test('T-0053-AC2 a screen is the kit event with screen_name', () async {
      final rig = Rig();

      rig.analytics.screen('characters_list', params: {'tab': 'all'});
      await settle();

      final event = rig.sink.events.last;
      expect(event.name, screenViewEventName);
      expect(event.params, {'tab': 'all', 'screen_name': 'characters_list'});
    });

    test('T-0053-AC2 a screen name may start with a reserved prefix', () async {
      final rig = Rig();

      rig.analytics.screen('mc_internal');
      await settle();

      expect(rig.sink.screens, ['mc_internal']);
    });

    test('T-0053-AC2 a user property keeps its typed value', () async {
      final rig = Rig();

      rig.analytics.setUserProperty('plan', 'free');
      rig.analytics.setUserProperty('age', 30);
      rig.analytics.setUserProperty('score', 1.5);
      rig.analytics.setUserProperty('beta', true);
      await settle();

      expect(
        rig.sink.records.whereType<AnalyticsUserPropertyRecord>().map(
          (r) => (r.key, r.value),
        ),
        [('plan', 'free'), ('age', 30), ('score', 1.5), ('beta', true)],
      );
    });
  });
}
