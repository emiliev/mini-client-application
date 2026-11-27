import 'dart:async';
import 'dart:io';

import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_session/mc_session.dart';
import 'package:test/test.dart';

import 'rig.dart';

/// How often the backend saw `GET /v1/flags`.
int _flagCalls(Rig rig) => rig.backend.recentTraffic
    .where((t) => t.method == 'GET' && t.path == '/v1/flags')
    .length;

void main() {
  final rigs = <Rig>[];
  Future<Rig> make({
    String env = 'dev',
    MockDomain? domain,
    bool holding = false,
    bool start = true,
  }) async {
    final rig = await Rig.create(
      env: env,
      domain: domain ?? const PlatformMockDomain(),
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

  Future<Object?> storedCacheUser(Rig rig) async {
    final cache = (await rig.store.read(flagsCacheKey)).getOrNull();
    return cache is Map ? cache['userId'] : 'no cache';
  }

  group('T-0052-AC3 fetch on start and on a session change', () {
    test(
      'T-0052-AC3 start fetches once, anonymously, without a bearer',
      () async {
        final rig = await make(holding: true);
        await rig.gate.waitForHeld(1);
        expect(rig.gate.held.single.authorization, isNull);
        rig.gate.held.single.release();
        await rig.settle();
        expect(_flagCalls(rig), 1);
        expect(rig.flags.value(searchLayout), Layout.grid);
      },
    );

    test('T-0052-AC3 a user switch refetches with that user\'s bearer, and '
        'the targeted flag changes value', () async {
      final rig = await make();
      await rig.flags.refresh();
      expect(rig.flags.value(searchLayout), Layout.grid);
      expect(rig.flags.value(promoBanner), isFalse);
      await rig.signIn('u-100');
      // No call to the flags API in between: the stream alone did it.
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list);
      expect(rig.flags.value(promoBanner), isTrue);
      expect(_flagCalls(rig), 2);
      expect(await storedCacheUser(rig), 'u-100');
      // Another user, then signed out.
      await rig.signIn('u-101');
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.grid);
      expect(rig.flags.value(pageSize), 40);
      await rig.signOut();
      await rig.settle();
      expect(rig.flags.value(pageSize), 20);
      expect(rig.flags.value(promoBanner), isFalse);
      expect(await storedCacheUser(rig), isNull);
    });

    test(
      'T-0052-AC3 the request of a signed-in user carries the bearer',
      () async {
        final rig = await make(holding: true, start: false);
        await rig.signIn('u-100');
        await rig.gate.waitForHeld(1);
        expect(
          rig.gate.held.single.authorization,
          'Bearer ${mintAccessToken('u-100', 1)}',
        );
      },
    );

    test('T-0052-AC3 a sign-in as the same user starts a new epoch and a new '
        'fetch, and the values stay meanwhile (no flicker)', () async {
      final rig = await make();
      await rig.signIn('u-100');
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list);
      rig.gate.holding = true;
      await rig.signIn('u-100', 2);
      // Same user: no authState event, so the new epoch is noticed by the
      // next read (documented).
      expect(rig.flags.value(searchLayout), Layout.list);
      await rig.gate.waitForHeld(1);
      expect(rig.flags.value(searchLayout), Layout.list, reason: 'kept');
      expect(rig.flags.value(promoBanner), isTrue);
      rig.gate.held.single.release();
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list);
      expect(_flagCalls(rig), 3);
    });

    test('T-0052-AC3 a user switch forgets the other user\'s values until '
        'the new fetch lands (they are not last-known-good for another '
        'user)', () async {
      final rig = await make();
      await rig.signIn('u-100');
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list);
      rig.gate.holding = true;
      await rig.signIn('u-101');
      await rig.gate.waitForHeld(1);
      expect(
        rig.flags.value(searchLayout),
        Layout.compact,
        reason: 'the default, not u-100\'s list',
      );
      expect(rig.flags.value(pageSize), 10);
      rig.gate.held.single.release();
      await rig.settle();
      expect(rig.flags.value(pageSize), 40);
    });

    test('T-0052-AC3 concurrent refresh calls share one request', () async {
      final rig = await make(start: false);
      await Future.wait([
        rig.flags.refresh(),
        rig.flags.refresh(),
        rig.flags.refresh(),
      ]);
      expect(_flagCalls(rig), 1);
      await rig.flags.refresh();
      expect(_flagCalls(rig), 2, reason: 'not joined once it has finished');
    });
  });

  group('T-0052-AC3 the epoch rule: a result for an old session is '
      'dropped (held responses, both orders)', () {
    test('T-0052-AC3 order 1: the old response is released after the switch '
        'but before the new one, and is dropped', () async {
      final rig = await make(holding: true);
      await rig.gate.waitForHeld(1); // anonymous, epoch 0
      await rig.signIn('u-100'); // epoch 1, a new fetch
      await rig.gate.waitForHeld(2);
      expect(rig.gate.held[1].authorization, isNotNull);

      rig.gate.held[0].release(); // the old anonymous answer: grid
      await rig.settle();
      expect(
        rig.flags.value(searchLayout),
        Layout.compact,
        reason: 'neither the anonymous grid nor anything else was applied',
      );
      expect(rig.flags.value(pageSize), 10);
      expect(rig.store.existsSync(flagsCacheKey), isFalse, reason: 'no write');

      rig.gate.held[1].release(); // the new answer: list
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list);
      expect(await storedCacheUser(rig), 'u-100');
    });

    test('T-0052-AC3 order 2: the new response lands first, then the old '
        'one is released, and it changes nothing', () async {
      final rig = await make(holding: true);
      await rig.gate.waitForHeld(1);
      await rig.signIn('u-100');
      await rig.gate.waitForHeld(2);

      rig.gate.held[1].release();
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list);
      expect(await storedCacheUser(rig), 'u-100');

      rig.gate.held[0].release();
      await rig.settle();
      expect(rig.flags.value(searchLayout), Layout.list, reason: 'not grid');
      expect(rig.flags.value(promoBanner), isTrue);
      expect(
        await storedCacheUser(rig),
        'u-100',
        reason: 'cache not clobbered',
      );
    });

    test('T-0052-AC3 a sign-out while a signed-in response is held: that '
        'response is dropped, in both orders', () async {
      for (final newFirst in [true, false]) {
        final rig = await make(start: false);
        await rig.signIn('u-100');
        await rig.settle();
        rig.gate.holding = true;
        await rig.signIn('u-101'); // held[0]: u-101's answer (epoch 2)
        await rig.signOut(); // epoch 3, held[1]: anonymous
        await rig.gate.waitForHeld(2);
        final tag = 'newFirst=$newFirst';
        if (newFirst) {
          rig.gate.held[1].release();
          rig.gate.held[0].release();
        } else {
          rig.gate.held[0].release();
          rig.gate.held[1].release();
        }
        await rig.settle();
        expect(rig.flags.value(pageSize), 20, reason: tag);
        expect(rig.flags.value(searchLayout), Layout.grid, reason: tag);
        expect(await storedCacheUser(rig), isNull, reason: tag);
      }
    });

    test(
      'T-0052-AC3 negative control: a response of the current epoch is '
      'applied (the drop is about the epoch, not about held responses)',
      () async {
        final rig = await make(holding: true);
        await rig.gate.waitForHeld(1);
        rig.gate.held[0].release();
        await rig.settle();
        expect(rig.flags.value(searchLayout), Layout.grid);
        expect(await storedCacheUser(rig), isNull);
        expect(rig.store.existsSync(flagsCacheKey), isTrue);
      },
    );

    test(
      'T-0052-AC3 a response that arrives after dispose is dropped',
      () async {
        final rig = await make(holding: true);
        await rig.gate.waitForHeld(1);
        await rig.flags.dispose();
        rig.gate.held[0].release();
        await rig.settle();
        expect(rig.store.existsSync(flagsCacheKey), isFalse);
        expect(rig.flags.value(searchLayout), Layout.compact);
      },
    );
  });

  group('T-0052-AC3 a failed fetch keeps the values and never throws', () {
    Future<void> expectKeeps(Rig rig, void Function() breakBackend) async {
      await rig.flags.refresh();
      expect(rig.flags.value(pageSize), 20);
      breakBackend();
      await expectLater(rig.flags.refresh(), completes);
      expect(rig.flags.value(pageSize), 20);
      expect(rig.flags.value(searchLayout), Layout.grid);
      expect(rig.reports.any((m) => m.contains('fetch failed')), isTrue);
    }

    test('T-0052-AC3 a 500 keeps the values', () async {
      final rig = await make(start: false);
      await expectKeeps(
        rig,
        () => rig.backend.addFailure(
          const FailureRule('GET', '/v1/flags', FailureKind.http(500)),
        ),
      );
    });

    test('T-0052-AC3 offline keeps the values', () async {
      final rig = await make(start: false);
      await expectKeeps(
        rig,
        () => rig.backend.addFailure(
          const FailureRule('GET', '/v1/flags', FailureKind.offline()),
        ),
      );
    });

    test('T-0052-AC3 a timeout keeps the values', () async {
      final rig = await make(start: false);
      await expectKeeps(
        rig,
        () => rig.backend.addFailure(
          const FailureRule('GET', '/v1/flags', FailureKind.timeout()),
        ),
      );
    });

    test('T-0052-AC3 a 200 that is not JSON keeps the values', () async {
      final rig = await make(start: false);
      await expectKeeps(
        rig,
        () => rig.backend.addFailure(
          const FailureRule('GET', '/v1/flags', FailureKind.malformed()),
        ),
      );
    });

    for (final body in <Object?>[
      <Object?>[],
      'text',
      {'flags': 5},
      {'flags': <Object?>[]},
      {'experiments': <Object?>[]},
    ]) {
      test('T-0052-AC3 a body of the wrong shape ($body) keeps the values '
          'and is not cached', () async {
        final rig = await make(start: false, domain: _FixedBody(body));
        await rig.flags.refresh();
        expect(rig.flags.value(pageSize), 10);
        expect(rig.store.existsSync(flagsCacheKey), isFalse);
        expect(rig.reports.any((m) => m.contains('fetch failed')), isTrue);
      });
    }

    test('T-0052-AC3 a first fetch that fails leaves the defaults', () async {
      final rig = await make(
        start: false,
        domain: const FailingPlatformDomain(),
      );
      await expectLater(rig.flags.refresh(), completes);
      expect(rig.flags.value(pageSize), 10);
      expect(rig.flags.variant(storeHomeLayout), isNotEmpty);
    });

    test('T-0052-AC3 a failed cache write does not undo the fetch, and is '
        'reported', () async {
      final tmp = Directory.systemTemp.createTempSync('mc_ff_blocked');
      addTearDown(() => tmp.deleteSync(recursive: true));
      // A file where the store directory should be: every write fails.
      File('${tmp.path}/blocked').writeAsStringSync('x');
      final rig = await Rig.create(
        dir: Directory('${tmp.path}/blocked'),
        domain: const PlatformMockDomain(),
        start: false,
      );
      rigs.add(rig);
      await rig.flags.refresh();
      expect(rig.flags.value(pageSize), 20);
      expect(rig.reports.any((m) => m.contains('could not save')), isTrue);
    });
  });

  group('T-0052-AC3 review round', () {
    test('T-0052-AC3 a watch-only consumer sees the new epoch of a same-user '
        're-sign-in, with no value() read', () async {
      final rig = await Rig.create(start: false);
      rigs.add(rig);
      rig.stub.flags = {'catalogue.page_size': 20};
      await rig.signIn('u-100');
      await rig.flags.refresh();
      final events = <int>[];
      final sub = rig.flags.watch(pageSize).listen(events.add);
      await rig.settle();
      expect(events, [20]);
      rig.stub.flags = {'catalogue.page_size': 30};
      await rig.signIn('u-100', 2); // no authState event, nobody reads
      await rig.settle();
      expect(events, [20, 30]);
      await sub.cancel();
    });

    test('T-0052-AC3 dispose ends every watch stream with done, and a watch '
        'after dispose emits its value and ends', () async {
      final rig = await make(start: false);
      final done = <Future<void>>[];
      for (var i = 0; i < 3; i++) {
        final completer = Completer<void>();
        done.add(completer.future);
        rig.flags.watch(pageSize).listen((_) {}, onDone: completer.complete);
      }
      await rig.settle();
      await rig.flags.dispose();
      await Future.wait(done).timeout(const Duration(seconds: 5));
      expect(
        await rig.flags
            .watch(pageSize)
            .toList()
            .timeout(const Duration(seconds: 5)),
        [10],
      );
    });

    test('T-0052-AC3 after dispose refresh() returns at once and sends no '
        'request, whatever the session does', () async {
      final rig = await make(start: false);
      await rig.flags.refresh();
      final before = _flagCalls(rig);
      expect(before, 1);
      await rig.flags.dispose();
      await rig.flags.refresh();
      await rig.signIn('u-100');
      await rig.flags.refresh();
      rig.flags.value(pageSize);
      rig.flags.start();
      await rig.settle();
      expect(_flagCalls(rig), before);
    });

    test('T-0052-AC3 the cache of a user is deleted when the user changes '
        'or signs out, so it does not stay on disk', () async {
      final rig = await make(start: false);
      await rig.signIn('u-100');
      await rig.flags.refresh();
      expect(await storedCacheUser(rig), 'u-100');
      // The backend fails from now on, so nothing rewrites the cache.
      rig.backend.addFailure(
        const FailureRule('GET', '/v1/flags', FailureKind.http(500)),
      );
      // Same-user sign-in keeps it.
      await rig.signIn('u-100', 2);
      await rig.flags.refresh();
      await rig.settle();
      expect(rig.store.existsSync(flagsCacheKey), isTrue);
      await rig.signOut();
      await rig.flags.refresh();
      await rig.settle();
      expect(rig.store.existsSync(flagsCacheKey), isFalse);
      // Another user: the previous user's body is not left either.
      final other = await make(start: false);
      await other.signIn('u-100');
      await other.flags.refresh();
      other.backend.addFailure(
        const FailureRule('GET', '/v1/flags', FailureKind.http(500)),
      );
      await other.signIn('u-101');
      await other.flags.refresh();
      await other.settle();
      expect(other.store.existsSync(flagsCacheKey), isFalse);
      // And a restart as anonymous with the backend failing sees defaults.
      final restarted = await rig.relaunch(
        domain: const FailingPlatformDomain(),
        start: false,
      );
      rigs.add(restarted);
      await restarted.flags.refresh();
      expect(restarted.flags.value(searchLayout), Layout.compact);
    });
  });

  group('T-0052-AC3 session paths', () {
    test('T-0052-AC3 a read right after a user switch, before any stream '
        'event, does not return the other user\'s values', () async {
      final rig = await make(start: false);
      await rig.signIn('u-100');
      await rig.flags.refresh();
      expect(rig.flags.value(searchLayout), Layout.list);
      // The epoch moves at once inside signIn; the stream events come later.
      final pending = rig.session.signIn(
        userId: 'u-101',
        tokens: AuthTokens(
          accessToken: mintAccessToken('u-101', 1),
          refreshToken: mintRefreshToken('u-101', 1),
        ),
      );
      expect(rig.flags.value(searchLayout), Layout.compact);
      await pending;
    });

    test('T-0052-AC3 a session without epochChanges still refetches on a '
        'user switch, from authState alone, with no read', () async {
      final rig = await make(start: false);
      await rig.flags.dispose(); // only the reader-only flags fetch here
      final flags = await FeatureFlags.open(
        dio: rig.dio,
        session: _ReaderOnly(rig.session),
        store: rig.tracking,
        env: 'dev',
        monitoring: rig.monitoring,
      );
      flags.start();
      await rig.settle();
      final before = _flagCalls(rig);
      await rig.signIn('u-100');
      await rig.settle();
      expect(_flagCalls(rig), before + 1);
      await flags.dispose();
    });
  });

  group('T-0052-AC3 watch', () {
    test('T-0052-AC3 watch emits the current value, then only distinct '
        'changes', () async {
      final rig = await make(start: false);
      final events = <Layout>[];
      final sub = rig.flags.watch(searchLayout).listen(events.add);
      await rig.settle();
      expect(events, [Layout.compact], reason: 'the current value first');

      await rig.flags.refresh(); // compact -> grid
      expect(events, [Layout.compact, Layout.grid]);

      await rig.flags.refresh(); // same value again: nothing
      await rig.flags.set(searchLayout, Layout.grid); // same value: nothing
      await rig.settle();
      expect(events, [Layout.compact, Layout.grid]);

      await rig.flags.set(searchLayout, Layout.list); // override: list
      expect(events, [Layout.compact, Layout.grid, Layout.list]);

      await rig.flags.refresh(); // remote unchanged, override still wins
      expect(events.length, 3);

      await rig.flags.clear(searchLayout); // back to remote grid
      expect(events.last, Layout.grid);
      expect(events.length, 4);

      await rig.signIn('u-100'); // user switch: default, then list
      await rig.settle();
      expect(events.sublist(4), [Layout.compact, Layout.list]);
      await sub.cancel();
    });

    test('T-0052-AC3 watch of another flag is not woken by an unrelated '
        'change', () async {
      final rig = await make(start: false);
      final events = <String>[];
      final sub = rig.flags.watch(accent).listen(events.add);
      await rig.settle();
      await rig.flags.set(pageSize, 3);
      await rig.flags.refresh();
      await rig.settle();
      expect(events, ['blue', 'red'], reason: 'only its own changes');
      await sub.cancel();
    });

    test('T-0052-AC3 a cancelled watch stops, and a second one starts at '
        'the then-current value', () async {
      final rig = await make(start: false);
      final events = <Layout>[];
      final sub = rig.flags.watch(searchLayout).listen(events.add);
      await rig.settle();
      await sub.cancel();
      await rig.flags.refresh();
      await rig.settle();
      expect(events, [Layout.compact]);
      expect(await rig.flags.watch(searchLayout).first, Layout.grid);
    });
  });
}

/// Only the [SessionReader] face of a session (no `SessionEpochs`).
final class _ReaderOnly implements SessionReader {
  _ReaderOnly(this._inner);

  final SessionReader _inner;

  @override
  AuthStatus get status => _inner.status;
  @override
  bool get isSignedIn => _inner.isSignedIn;
  @override
  String? get userId => _inner.userId;
  @override
  String? get accessToken => _inner.accessToken;
  @override
  String? get refreshToken => _inner.refreshToken;
  @override
  int get epoch => _inner.epoch;
  @override
  Stream<AuthStatus> get authState => _inner.authState;
}

/// A domain that always answers `200` with [body].
final class _FixedBody implements MockDomain {
  _FixedBody(this.body);

  final Object? body;

  @override
  String get name => 'fixed_body';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      router.get('/v1/flags', (request, context) => MockResponse.ok(body));

  @override
  Map<String, MockScenario> get scenarios => const {};
}
