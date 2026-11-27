import 'dart:io';

import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:test/test.dart';

import 'rig.dart';

/// Writes a cache entry the way a previous run would have.
Future<void> _writeCache(
  Rig rig, {
  required String? userId,
  required Map<String, Object?> flags,
}) async {
  await rig.store.write(flagsCacheKey, {
    'userId': userId,
    'body': {'flags': flags, 'experiments': <Object?>[]},
  });
}

bool _ok(Result<void, FlagOverrideFailure> result) =>
    result.fold((_) => true, (_) => false);

void main() {
  final rigs = <Rig>[];
  Future<Rig> make({
    String env = 'dev',
    Directory? dir,
    StubFlagsDomain? stub,
    MockDomain? domain,
    bool holding = false,
    bool start = true,
  }) async {
    final rig = await Rig.create(
      env: env,
      dir: dir,
      stub: stub,
      domain: domain,
      holding: holding,
      start: start,
    );
    rigs.add(rig);
    return rig;
  }

  Future<Rig> relaunch(
    Rig from, {
    String? env,
    MockDomain? domain,
    bool holding = false,
    bool start = true,
  }) async {
    final rig = await from.relaunch(
      env: env,
      domain: domain,
      holding: holding,
      start: start,
    );
    rigs.add(rig);
    return rig;
  }

  tearDown(() async {
    for (final rig in rigs) {
      await rig.dispose();
    }
    rigs.clear();
  });

  group('T-0052-AC1 evaluation order: one test per transition', () {
    test('T-0052-AC1 the default wins when no other source has a value, '
        'also while the first fetch is still held', () async {
      final rig = await make(holding: true);
      rig.stub.flags = {'catalogue.page_size': 20};
      expect(rig.flags.value(pageSize), 10);
      expect(rig.flags.value(promoBanner), isTrue);
      expect(rig.flags.value(accent), 'blue');
      expect(rig.flags.value(searchLayout), Layout.compact);
      await rig.gate.waitForHeld(1);
      expect(rig.flags.value(pageSize), 10, reason: 'nothing applied yet');
    });

    test(
      'T-0052-AC1 the remote value of this epoch beats the default',
      () async {
        final rig = await make();
        rig.stub.flags = {
          'catalogue.page_size': 20,
          'settings.accent': 'red',
          'store.promo_banner': false,
          'search.layout': 'grid',
        };
        await rig.flags.refresh();
        expect(rig.flags.value(pageSize), 20);
        expect(rig.flags.value(accent), 'red');
        expect(rig.flags.value(promoBanner), isFalse);
        expect(rig.flags.value(searchLayout), Layout.grid);
      },
    );

    test('T-0052-AC1 a key the server never sends stays the default, and '
        'unknown remote keys are ignored without a report', () async {
      final rig = await make();
      rig.stub.flags = {
        'catalogue.page_size': 20,
        'some.other.feature': 'x',
        'another': 3,
      };
      await rig.flags.refresh();
      expect(rig.flags.value(unknownToServer), isFalse);
      expect(rig.flags.value(pageSize), 20);
      expect(rig.reports, isEmpty);
    });

    test('T-0052-AC1 the last-known-good value is used after a restart with '
        'the backend failing', () async {
      final first = await make();
      first.stub.flags = {'catalogue.page_size': 20, 'settings.accent': 'red'};
      await first.flags.refresh();
      final second = await relaunch(
        first,
        domain: const FailingPlatformDomain(),
      );
      // Before and after the failed fetch.
      expect(second.flags.value(pageSize), 20);
      await second.flags.refresh();
      expect(second.flags.value(pageSize), 20);
      expect(second.flags.value(accent), 'red');
      expect(second.flags.value(promoBanner), isTrue, reason: 'not cached');
      expect(second.reports.any((m) => m.contains('fetch failed')), isTrue);
    });

    test('T-0052-AC1 the last-known-good value is used while the first fetch '
        'of a restart is still held, and the remote value of this epoch then '
        'beats it', () async {
      final first = await make();
      first.stub.flags = {'catalogue.page_size': 20};
      await first.flags.refresh();
      final second = await relaunch(first, holding: true);
      second.stub.flags = {'catalogue.page_size': 30};
      expect(second.flags.value(pageSize), 20, reason: 'last-known-good');
      await second.gate.waitForHeld(1);
      expect(second.flags.value(pageSize), 20);
      second.gate.held.single.release();
      await second.settle();
      expect(second.flags.value(pageSize), 30, reason: 'this epoch wins');
    });

    test('T-0052-AC1 a successful fetch ends the last-known-good: a key the '
        'server no longer sends is the default, not the old value', () async {
      final first = await make();
      first.stub.flags = {'catalogue.page_size': 20, 'settings.accent': 'red'};
      await first.flags.refresh();
      final second = await relaunch(first);
      second.stub.flags = {'settings.accent': 'green'};
      await second.flags.refresh();
      expect(second.flags.value(accent), 'green');
      expect(second.flags.value(pageSize), 10);
    });

    test('T-0052-AC1 a local override beats the remote value, the '
        'last-known-good and the default; clearing it falls through in '
        'order', () async {
      final first = await make();
      first.stub.flags = {'catalogue.page_size': 20};
      await first.flags.refresh();
      final rig = await relaunch(first, holding: true);
      rig.stub.flags = {'catalogue.page_size': 30};
      expect(rig.flags.value(pageSize), 20, reason: 'last-known-good');
      expect(_ok(await rig.flags.set(pageSize, 99)), isTrue);
      expect(rig.flags.value(pageSize), 99, reason: 'beats last-known-good');
      await rig.gate.waitForHeld(1);
      rig.gate.held.single.release();
      await rig.settle();
      expect(rig.flags.value(pageSize), 99, reason: 'beats the remote 30');
      await rig.flags.clear(pageSize);
      expect(rig.flags.value(pageSize), 30, reason: 'then the remote');
      await rig.flags.set(accent, 'purple');
      expect(rig.flags.value(accent), 'purple', reason: 'beats the default');
      await rig.flags.clearAll();
      expect(rig.flags.value(accent), 'blue');
      expect(rig.flags.value(pageSize), 30);
    });

    test('T-0052-AC1 an override survives a restart, and is cleared on '
        'disk by clearAll', () async {
      final first = await make();
      await first.flags.set(pageSize, 99);
      await first.flags.set(searchLayout, Layout.list);
      await first.flags.forceVariant(storeHomeLayout, 'rich');
      final second = await relaunch(first, start: false);
      expect(second.flags.value(pageSize), 99);
      expect(second.flags.value(searchLayout), Layout.list);
      expect(second.flags.variant(storeHomeLayout), 'rich');
      await second.flags.clearAll();
      expect(second.store.existsSync(flagsOverridesKey), isFalse);
      final third = await relaunch(second, start: false);
      expect(third.flags.value(pageSize), 10);
    });

    for (final env in ['release', 'prod', 'staging', 'production', '']) {
      test('T-0052-AC1 an override is ignored in the release-like env '
          '"$env": rejected, and a saved one is not read', () async {
        final dev = await make();
        await dev.flags.set(pageSize, 99);
        await dev.flags.forceVariant(storeHomeLayout, 'rich');
        dev.stub.flags = {'catalogue.page_size': 20};
        await dev.flags.refresh();
        expect(dev.flags.value(pageSize), 99, reason: 'control: dev accepts');

        final rig = await relaunch(dev, env: env);
        expect(rig.flags.isEnabled, isFalse);
        await rig.flags.refresh();
        expect(rig.flags.value(pageSize), 20, reason: 'saved override unread');
        expect(rig.flags.variant(storeHomeLayout), isNot(equals('rich')));
        for (final result in [
          await rig.flags.set(pageSize, 5),
          await rig.flags.clear(pageSize),
          await rig.flags.clearAll(),
          await rig.flags.forceVariant(storeHomeLayout, 'rich'),
          await rig.flags.clearVariant(storeHomeLayout),
        ]) {
          expect(
            result.fold((_) => null, (f) => f.reason),
            FlagOverrideFailureReason.releaseEnvironment,
          );
        }
        expect(rig.flags.value(pageSize), 20, reason: 'set was rejected');
        // Nothing was written, nothing was deleted: dev still sees it.
        final back = await relaunch(rig, env: 'dev', start: false);
        expect(back.flags.value(pageSize), 99);
        expect(back.flags.variant(storeHomeLayout), 'rich');
      });
    }

    for (final env in ['dev', 'e2e', 'perf', 'test']) {
      test('T-0052-AC1 overrides are accepted in the env "$env"', () async {
        final rig = await make(env: env);
        expect(rig.flags.isEnabled, isTrue);
        expect(isReleaseLikeEnv(env), isFalse);
        expect(_ok(await rig.flags.set(pageSize, 7)), isTrue);
        expect(rig.flags.value(pageSize), 7);
      });
    }

    test(
      'T-0052-AC1 a wrong-typed remote value falls back to the default '
      'and is reported once, however often it is read or refetched',
      () async {
        final rig = await make();
        rig.stub.flags = {
          'catalogue.page_size': 'twenty',
          'store.promo_banner': 1,
          'search.layout': 'carousel',
          'settings.accent': 'red',
        };
        await rig.flags.refresh();
        for (var i = 0; i < 4; i++) {
          expect(rig.flags.value(pageSize), 10);
          expect(rig.flags.value(promoBanner), isTrue);
          expect(rig.flags.value(searchLayout), Layout.compact);
          expect(rig.flags.value(accent), 'red');
        }
        await rig.flags.refresh();
        await rig.settle();
        expect(rig.flags.value(pageSize), 10);
        for (final key in [
          'catalogue.page_size',
          'store.promo_banner',
          'search.layout',
        ]) {
          expect(
            rig.reports.where((m) => m.contains(key)).length,
            1,
            reason: key,
          );
        }
        expect(
          rig.reports.where((m) => m.contains('settings.accent')),
          isEmpty,
        );
      },
    );

    test('T-0052-AC1 which values count as the wrong type', () async {
      final rig = await make();
      rig.stub.flags = {
        'catalogue.page_size': 5.5,
        'store.promo_banner': 'true',
        'settings.accent': 7,
        'search.layout': 3,
      };
      await rig.flags.refresh();
      expect(rig.flags.value(pageSize), 10, reason: 'a fraction is not an int');
      expect(rig.flags.value(promoBanner), isTrue);
      expect(rig.flags.value(accent), 'blue');
      expect(rig.flags.value(searchLayout), Layout.compact);
      expect(rig.reports, hasLength(4));
      // A JSON null is "no value": the default, and no report.
      rig.stub.flags = {'catalogue.page_size': null};
      await rig.flags.refresh();
      expect(rig.flags.value(pageSize), 10);
      expect(rig.reports, hasLength(4));
    });

    test('T-0052-AC1 a wrong-typed saved override falls to the remote value '
        'and is reported once', () async {
      final rig = await make(start: false);
      await rig.store.write(flagsOverridesKey, {
        'flags': {'catalogue.page_size': 'lots'},
        'variants': <String, String>{},
      });
      final second = await relaunch(rig);
      second.stub.flags = {'catalogue.page_size': 20};
      await second.flags.refresh();
      expect(second.flags.value(pageSize), 20);
      expect(second.flags.value(pageSize), 20);
      expect(
        second.reports.where((m) => m.contains('catalogue.page_size')).length,
        1,
      );
    });

    test('T-0052-AC1 the last-known-good belongs to one user: another '
        "user's cache is not used", () async {
      final rig = await make(start: false);
      await _writeCache(
        rig,
        userId: 'u-101',
        flags: {'catalogue.page_size': 77},
      );
      final anonymous = await relaunch(
        rig,
        domain: const FailingPlatformDomain(),
      );
      await anonymous.flags.refresh();
      expect(anonymous.flags.value(pageSize), 10, reason: 'cache is for u-101');
      // Control: the same cache is used by the user it belongs to.
      await anonymous.signIn('u-101');
      final owner = await relaunch(
        anonymous,
        domain: const FailingPlatformDomain(),
      );
      expect(owner.session.userId, 'u-101');
      expect(owner.flags.value(pageSize), 77);
    });

    test(
      'T-0052-AC1 a corrupt, wrong-shaped or unreadable cache is ignored',
      () async {
        final rig = await make(start: false);
        for (final junk in <Object?>[
          'junk',
          42,
          <Object?>[],
          {'userId': null},
          {'userId': null, 'body': 5},
          {
            'userId': null,
            'body': {'flags': 5},
          },
          {
            'userId': null,
            'body': {'experiments': <Object?>[]},
          },
        ]) {
          await rig.store.write(flagsCacheKey, junk);
          final next = await relaunch(
            rig,
            domain: const FailingPlatformDomain(),
          );
          await next.flags.refresh();
          expect(next.flags.value(pageSize), 10, reason: '$junk');
        }
        // Not JSON at all.
        File(
          '${rig.dir.path}/${_hex(flagsCacheKey)}.json',
        ).writeAsStringSync('{not json');
        final last = await relaunch(rig, domain: const FailingPlatformDomain());
        await last.flags.refresh();
        expect(last.flags.value(pageSize), 10);
      },
    );

    test(
      'T-0052-AC1 a failed fetch after a good one keeps the values',
      () async {
        final rig = await make();
        rig.stub.flags = {'catalogue.page_size': 20};
        await rig.flags.refresh();
        expect(rig.flags.value(pageSize), 20);
        rig.backend.addFailure(
          const FailureRule('GET', '/v1/flags', FailureKind.http(500)),
        );
        await rig.flags.refresh();
        expect(rig.flags.value(pageSize), 20);
        expect(rig.reports.any((m) => m.contains('fetch failed')), isTrue);
      },
    );

    test(
      'T-0052-AC1 the fixtures: the default set serves the documented '
      'values, and platform.flags_malformed falls back and reports',
      () async {
        final rig = await make(domain: const PlatformMockDomain());
        await rig.flags.refresh();
        expect(rig.flags.value(pageSize), 20);
        expect(rig.flags.value(searchLayout), Layout.grid);
        expect(rig.flags.value(accent), 'red');
        expect(rig.flags.value(promoBanner), isFalse);
        final bad = await relaunch(
          rig,
          domain: const MalformedFlagsPlatformDomain(),
        );
        await bad.flags.refresh();
        expect(bad.flags.value(pageSize), 10);
        expect(bad.flags.value(promoBanner), isTrue);
        expect(bad.flags.value(searchLayout), Layout.compact);
        expect(bad.flags.value(accent), 'red', reason: 'the valid one is used');
        expect(
          bad.reports.where((m) => m.contains('catalogue.page_size')).length,
          1,
        );
      },
    );
  });
}

String _hex(String key) =>
    key.codeUnits.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
