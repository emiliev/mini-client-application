import 'dart:io';

import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

void main() {
  late Directory dir;
  late FileStore store;
  late EventBus bus;
  late List<SessionChanged> events;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mc_session_test');
    store = FileStore(dir);
    bus = EventBus();
    events = [];
    bus.on<SessionChanged>().listen(events.add);
  });

  tearDown(() async {
    await bus.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<Session> open() => Session.restore(store, bus: bus);

  group('T-0039-AC4 persistence', () {
    test(
      'T-0039-AC4 a new instance on the same store restores the session',
      () async {
        final first = await open();
        await first.signIn(userId: 'u-1', tokens: _tokens);

        final second = await open();

        expect(second.status, AuthStatus.signedIn);
        expect(second.isSignedIn, isTrue);
        expect(second.userId, 'u-1');
        expect(second.accessToken, 'access-1');
        expect(second.refreshToken, 'refresh-1');
      },
    );

    test('T-0039-AC4 updated tokens survive a new instance', () async {
      final first = await open();
      await first.signIn(userId: 'u-1', tokens: _tokens);
      await first.updateTokens(
        const AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2'),
      );

      final second = await open();

      expect(second.accessToken, 'access-2');
      expect(second.userId, 'u-1');
    });

    test('T-0039-AC4 an empty store reads as signed out', () async {
      final session = await open();

      expect(session.status, AuthStatus.signedOut);
      expect(session.isSignedIn, isFalse);
      expect(session.userId, isNull);
      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
    });

    test(
      'T-0039-AC4 sign-out is saved: a new instance is signed out',
      () async {
        final first = await open();
        await first.signIn(userId: 'u-1', tokens: _tokens);
        await first.signOut();

        expect((await open()).status, AuthStatus.signedOut);
      },
    );

    test(
      'T-0039-AC4 a corrupt store reads as signed out and heals on sign-in',
      () async {
        _writeRaw(dir, '{broken');

        final session = await open();
        expect(session.status, AuthStatus.signedOut);

        await session.signIn(userId: 'u-1', tokens: _tokens);

        expect((await open()).accessToken, 'access-1');
      },
    );

    test('T-0039-AC4 a value of the wrong shape reads as signed out', () async {
      for (final raw in [
        '[]',
        '"text"',
        '{"userId": "u-1"}',
        '{"accessToken": "a", "refreshToken": "r"}',
        '{"userId": "", "accessToken": "a", "refreshToken": "r"}',
        '{"userId": "u-1", "accessToken": "", "refreshToken": "r"}',
        '{"userId": 7, "accessToken": "a", "refreshToken": "r"}',
      ]) {
        _writeRaw(dir, raw);

        expect((await open()).status, AuthStatus.signedOut, reason: raw);
      }
    });

    test('T-0039-AC4 sign-out heals a corrupt store', () async {
      _writeRaw(dir, '{broken');
      final session = await open();

      final result = await session.signOut();

      expect(result.fold((_) => true, (_) => false), isTrue);
      expect((await store.read('session')).getOrNull(), isNull);
    });

    test(
      'T-0039-AC4 a fast sign-in then sign-out leaves the store signed out',
      () async {
        final session = await open();

        final a = session.signIn(userId: 'u-1', tokens: _tokens);
        final b = session.signOut();
        await Future.wait([a, b]);

        expect(session.status, AuthStatus.signedOut);
        expect((await open()).status, AuthStatus.signedOut);
      },
    );

    test(
      'T-0039-AC4 a save failure is a value; memory keeps the change',
      () async {
        final blocked = File('${dir.path}/blocked')..writeAsStringSync('x');
        final session = await Session.restore(
          FileStore(Directory(blocked.path)),
        );

        final result = await session.signIn(userId: 'u-1', tokens: _tokens);

        expect(result.fold((_) => 'ok', (f) => f), isA<StorageFailure>());
        expect(session.isSignedIn, isTrue);
      },
    );

    test('T-0039-AC4 a custom key keeps two sessions apart', () async {
      final a = await Session.restore(store, key: 'a');
      await a.signIn(userId: 'u-1', tokens: _tokens);

      expect((await Session.restore(store, key: 'b')).isSignedIn, isFalse);
      expect((await Session.restore(store, key: 'a')).isSignedIn, isTrue);
    });
  });

  group('T-0039-AC2 events and state', () {
    test(
      'T-0039-AC2 sign-in and sign-out publish SessionChanged and the stream',
      () async {
        final session = await open();
        final states = <AuthStatus>[];
        session.authState.listen(states.add);

        await session.signIn(userId: 'u-1', tokens: _tokens);
        await session.signOut();
        await pumpEventQueue();

        expect(states, [AuthStatus.signedIn, AuthStatus.signedOut]);
        expect(events, const [
          SessionChanged(AuthStatus.signedIn),
          SessionChanged(AuthStatus.signedOut),
        ]);
      },
    );

    test('T-0039-AC2 a token refresh publishes nothing', () async {
      final session = await open();
      await session.signIn(userId: 'u-1', tokens: _tokens);
      await pumpEventQueue();
      events.clear();

      await session.updateTokens(
        const AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2'),
      );
      await pumpEventQueue();

      expect(events, isEmpty);
      expect(session.accessToken, 'access-2');
    });

    test('T-0039-AC2 signing out when signed out publishes nothing', () async {
      final session = await open();

      await session.signOut();
      await pumpEventQueue();

      expect(events, isEmpty);
    });

    test(
      'T-0039-AC2 updateTokens after a sign-out cannot revive the session',
      () async {
        final session = await open();
        await session.signIn(userId: 'u-1', tokens: _tokens);
        await session.signOut();

        await session.updateTokens(
          const AuthTokens(accessToken: 'late', refreshToken: 'late'),
        );

        expect(session.status, AuthStatus.signedOut);
        expect((await open()).status, AuthStatus.signedOut);
      },
    );

    test('T-0039-AC2 the state changes before the save finishes', () async {
      final session = await open();

      final saving = session.signIn(userId: 'u-1', tokens: _tokens);

      expect(session.accessToken, 'access-1');
      await saving;
    });

    test(
      'T-0039-AC2 a session without a bus works, and dispose closes the stream',
      () async {
        final session = await Session.restore(store);
        var done = false;
        session.authState.listen((_) {}, onDone: () => done = true);

        await session.signIn(userId: 'u-1', tokens: _tokens);
        await session.dispose();
        await session.signOut();
        await pumpEventQueue();

        expect(done, isTrue);
        expect(session.status, AuthStatus.signedOut);
      },
    );

    test('T-0039-AC2 SessionChanged compares by status', () {
      expect(
        const SessionChanged(AuthStatus.signedIn),
        const SessionChanged(AuthStatus.signedIn),
      );
      expect(
        const SessionChanged(AuthStatus.signedIn).hashCode,
        const SessionChanged(AuthStatus.signedIn).hashCode,
      );
      expect(
        const SessionChanged(AuthStatus.signedIn),
        isNot(const SessionChanged(AuthStatus.signedOut)),
      );
      expect(
        const SessionChanged(AuthStatus.signedOut).toString(),
        'SessionChanged(signedOut)',
      );
    });
  });

  group('T-0039-AC2 sessions have epochs', () {
    test(
      'T-0039-AC2 the epoch changes on sign-in and sign-out, not on a refresh',
      () async {
        final session = await open();
        final start = session.epoch;

        await session.signIn(userId: 'u-1', tokens: _tokens);
        final signedIn = session.epoch;
        await session.updateTokens(
          const AuthTokens(accessToken: 'a2', refreshToken: 'r2'),
        );
        final refreshed = session.epoch;
        await session.signOut();
        final signedOut = session.epoch;
        await session.signOut();

        expect(signedIn, isNot(start));
        expect(refreshed, signedIn);
        expect(signedOut, isNot(refreshed));
        expect(
          session.epoch,
          signedOut,
          reason: 'signing out twice is one change',
        );
      },
    );

    test('T-0039-AC2 updateTokens for an old epoch changes nothing', () async {
      final session = await open();
      await session.signIn(userId: 'u-1', tokens: _tokens);
      final old = session.epoch;
      await session.signOut();
      await session.signIn(
        userId: 'u-2',
        tokens: const AuthTokens(accessToken: 'b', refreshToken: 'b-r'),
      );

      await session.updateTokens(
        const AuthTokens(accessToken: 'late', refreshToken: 'late'),
        epoch: old,
      );

      expect(session.userId, 'u-2');
      expect(session.accessToken, 'b');
      expect((await open()).accessToken, 'b');
    });

    test('T-0039-AC2 updateTokens for the current epoch applies', () async {
      final session = await open();
      await session.signIn(userId: 'u-1', tokens: _tokens);

      await session.updateTokens(
        const AuthTokens(accessToken: 'a2', refreshToken: 'r2'),
        epoch: session.epoch,
      );

      expect(session.accessToken, 'a2');
    });

    test(
      'T-0039-AC2 signOut for an old epoch does not end the new session',
      () async {
        final session = await open();
        await session.signIn(userId: 'u-1', tokens: _tokens);
        final old = session.epoch;
        await session.signOut();
        await session.signIn(userId: 'u-2', tokens: _tokens);
        await pumpEventQueue();
        events.clear();

        await session.signOut(ifEpoch: old);
        await pumpEventQueue();

        expect(session.userId, 'u-2');
        expect(events, isEmpty);
        expect((await open()).userId, 'u-2');
      },
    );

    test('T-0039-AC2 signOut for the current epoch ends the session', () async {
      final session = await open();
      await session.signIn(userId: 'u-1', tokens: _tokens);

      await session.signOut(ifEpoch: session.epoch);

      expect(session.isSignedIn, isFalse);
    });

    test('T-0039-AC2 a repeat sign-in of the same user announces nothing, another user does', () async {
      final session = await open();
      await session.signIn(userId: 'u-1', tokens: _tokens);
      await pumpEventQueue();
      events.clear();

      await session.signIn(
        userId: 'u-1',
        tokens: const AuthTokens(accessToken: 'again', refreshToken: 'r'),
      );
      await pumpEventQueue();
      final repeat = [...events];
      await session.signIn(userId: 'u-2', tokens: _tokens);
      await pumpEventQueue();

      expect(repeat, isEmpty);
      expect(session.accessToken, 'access-1');
      expect(events, const [SessionChanged(AuthStatus.signedIn)]);
    });
  });

  group('T-0039-AC4 AuthTokens', () {
    test('T-0039-AC4 round-trips JSON and hides secrets in toString', () {
      expect(AuthTokens.fromJson(_tokens.toJson()), _tokens);
      expect(AuthTokens.fromJson(_tokens.toJson()).hashCode, _tokens.hashCode);
      expect(AuthTokens.fromJson({'accessToken': 'a'}), isNull);
      expect(AuthTokens.fromJson('x'), isNull);
      expect(_tokens.toString(), isNot(contains('access-1')));
    });
  });
}

void _writeRaw(Directory dir, String raw) {
  File('${dir.path}/${_hexKey('session')}.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(raw);
}

String _hexKey(String key) =>
    key.codeUnits.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<void> pumpEventQueue() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
