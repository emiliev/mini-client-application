// Signed in, the preferences follow the account (`mc_fixtures_identity`
// CONTRACT.md, `/v1/me/preferences`), by the merge rule of ADR-0013.
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:test/test.dart';

import 'rig.dart';

const _dark = AppearancePreferences(themeMode: AppearanceThemeMode.dark);

void main() {
  final rigs = <Rig>[];
  Future<Rig> make({String? signedInAs, MockBackend? backend}) async {
    final rig = await Rig.create(signedInAs: signedInAs, backend: backend);
    rigs.add(rig);
    return rig;
  }

  tearDown(() async {
    for (final rig in rigs) {
      await rig.quiesce();
    }
    for (final rig in rigs) {
      if (rig.dir.existsSync()) {
        rig.dir.deleteSync(recursive: true);
      }
    }
    rigs.clear();
  });

  group('T-0063-AC1 a signed-in launch shows the account', () {
    test(
      'T-0063-AC1 u-101 sees Dark, the seed, after one GET and no PATCH',
      () async {
        final rig = await make(signedInAs: collector);
        expect(rig.status, AppearanceSyncStatus.pending);
        await rig.settle();
        expect(rig.shown, _dark);
        expect(rig.status, AppearanceSyncStatus.synced);
        expect(rig.preferencesTraffic, ['GET']);
        // Kept on the device for the next launch.
        expect((rig.saved! as Map)['themeMode'], 'dark');
        expect((rig.saved! as Map)['pending'], isEmpty);
      },
    );

    test('T-0063-AC1 u-100 sees the defaults, and only the version seen is '
        'kept', () async {
      final rig = await make(signedInAs: reader);
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults);
      expect(rig.status, AppearanceSyncStatus.synced);
      // Only what the device saw is kept: the account's version.
      expect(rig.saved, {
        ...AppearancePreferences.defaults.toWire(),
        'pending': <String>[],
        'pendingFor': null,
        'seenVersion': 0,
        'seenFor': reader,
      });
    });
  });

  group('T-0063-AC6 a change while signed in', () {
    test('T-0063-AC6 goes to the account with ifVersion and only the '
        'changed key, and survives a restart from the account', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      expect(rig.status, AppearanceSyncStatus.synced);
      expect(rig.preferencesTraffic, ['GET', 'PATCH']);
      expect((await rig.account(collector))['themeMode'], 'light');
      expect((await rig.account(collector))['version'], 1);

      final again = await rig.relaunch();
      rigs.add(again);
      // The device's copy at once, then the account's.
      expect(again.shown.themeMode, AppearanceThemeMode.light);
      await again.settle();
      expect(again.shown.themeMode, AppearanceThemeMode.light);
      expect(again.status, AppearanceSyncStatus.synced);
    });

    test(
      'T-0063-AC6 changes made while a PATCH is out are sent after it, '
      'one request at a time, and the account ends with all of them',
      () async {
        final rig = await make(signedInAs: reader);
        await rig.settle();
        final held = rig.gate.holdNext('PATCH');
        final first = rig.appearance.change(
          themeMode: AppearanceThemeMode.dark,
        );
        final out = await held;
        expect(out.options.data, {'ifVersion': 0, 'themeMode': 'dark'});
        // Joined to the run that waits for the first PATCH.
        final second = rig.appearance.change(
          density: AppearanceDensity.compact,
        );
        final third = rig.appearance.change(reduceMotion: true);
        expect(rig.count('PATCH'), 1, reason: 'the first is still out');
        out.release();
        await Future.wait([first, second, third]);
        await rig.settle();
        expect(rig.count('PATCH'), 2);
        final account = await rig.account(reader);
        expect(account, containsPair('themeMode', 'dark'));
        expect(account, containsPair('density', 'compact'));
        expect(account, containsPair('reduceMotion', true));
        expect(account['version'], 2);
        expect(rig.status, AppearanceSyncStatus.synced);
        expect((rig.saved! as Map)['pending'], isEmpty);
      },
    );

    test('T-0063-AC6 a setting changed again while its PATCH is out stays '
        'pending and is sent again', () async {
      final rig = await make(signedInAs: reader);
      await rig.settle();
      final held = rig.gate.holdNext('PATCH');
      final first = rig.appearance.change(themeMode: AppearanceThemeMode.dark);
      final out = await held;
      final again = rig.appearance.change(themeMode: AppearanceThemeMode.light);
      out.release();
      await Future.wait([first, again]);
      await rig.settle();
      expect(rig.count('PATCH'), 2);
      expect((await rig.account(reader))['themeMode'], 'light');
      expect(rig.shown.themeMode, AppearanceThemeMode.light);
    });
  });

  group('T-0063-AC2 failures never block a local change', () {
    test('T-0063-AC2 with preferences_error the device copy stays in use, '
        'the status is offline, and Retry syncs', () async {
      final backend = MockBackend(domains: [const IdentityMockDomain()])
        ..useScenario('identity.preferences_error');
      final rig = await make(signedInAs: collector, backend: backend);
      await rig.settle();
      expect(rig.status, AppearanceSyncStatus.offline);
      expect(rig.shown, AppearancePreferences.defaults);
      expect(rig.warnings.last, contains('read'));

      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      expect(rig.shown.themeMode, AppearanceThemeMode.light);
      expect(rig.status, AppearanceSyncStatus.offline);
      expect((rig.saved! as Map)['pending'], ['themeMode']);
      expect((rig.saved! as Map)['pendingFor'], collector);

      backend.useScenario(null);
      await rig.appearance.retry();
      expect(rig.status, AppearanceSyncStatus.synced);
      // The account's dark lost to the unsynced local light.
      expect(rig.shown.themeMode, AppearanceThemeMode.light);
      expect((await rig.account(collector))['themeMode'], 'light');
      expect((rig.saved! as Map)['pending'], isEmpty);
    });

    test('T-0063-AC2 a PATCH that fails ends offline with the change kept '
        'and pending, and a later change sends both', () async {
      final backend = MockBackend(domains: [const IdentityMockDomain()]);
      final rig = await make(signedInAs: reader, backend: backend);
      await rig.settle();
      backend.useScenario('identity.preferences_error');
      await rig.appearance.change(themeMode: AppearanceThemeMode.dark);
      expect(rig.status, AppearanceSyncStatus.offline);
      expect(rig.shown.themeMode, AppearanceThemeMode.dark);
      backend.useScenario(null);
      await rig.appearance.change(density: AppearanceDensity.compact);
      expect(rig.status, AppearanceSyncStatus.synced);
      final account = await rig.account(reader);
      expect(account['themeMode'], 'dark');
      expect(account['density'], 'compact');
    });

    test(
      'T-0063-AC2 retry does nothing unless offline or a save failed',
      () async {
        final rig = await make(signedInAs: reader);
        await rig.settle();
        await rig.appearance.retry();
        await rig.settle();
        expect(rig.preferencesTraffic, ['GET']);
      },
    );

    test(
      'T-0063-AC2 a malformed account copy is offline, not applied',
      () async {
        final backend = MockBackend(domains: [const IdentityMockDomain()])
          ..failNext('GET', preferencesPath, const FailureKind.malformed());
        final rig = await make(signedInAs: collector, backend: backend);
        await rig.settle();
        expect(rig.status, AppearanceSyncStatus.offline);
        expect(rig.shown, AppearancePreferences.defaults);
      },
    );
  });

  group('T-0063-AC2 a 409 re-applies only the user change on current', () {
    test('T-0063-AC2 identity.preferences_conflict: exactly 2 PATCHes, the '
        'second on the version of current, ending synced', () async {
      final backend = MockBackend(domains: [const IdentityMockDomain()]);
      final rig = await make(signedInAs: collector, backend: backend);
      await rig.settle();
      backend.useScenario('identity.preferences_conflict');
      await rig.appearance.change(reduceMotion: true);
      expect(rig.count('PATCH'), 2);
      expect(rig.status, AppearanceSyncStatus.synced);
      expect(rig.shown, _dark.copyWith(reduceMotion: true));
      final account = await rig.account(collector);
      expect(account['reduceMotion'], true);
      expect(account['themeMode'], 'dark');
      expect(account['version'], 1);
    });

    test(
      'T-0063-AC2 another device changed another setting: it is kept, '
      'ours goes on top, and the status says the conflict was resolved',
      () async {
        final rig = await make(signedInAs: collector);
        await rig.settle();
        await rig.otherDeviceWrites(collector, {'density': 'compact'});
        await rig.appearance.change(themeMode: AppearanceThemeMode.light);
        expect(rig.count('PATCH'), 2);
        expect(rig.status, AppearanceSyncStatus.conflictResolved);
        expect(
          rig.shown,
          const AppearancePreferences(
            themeMode: AppearanceThemeMode.light,
            density: AppearanceDensity.compact,
          ),
        );
        final account = await rig.account(collector);
        expect(account['themeMode'], 'light');
        expect(account['density'], 'compact');
        expect(account['version'], 2);
      },
    );

    test('T-0063-AC2 another device changed the same setting: ours wins, and '
        'nothing else was taken, so it ends synced', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.otherDeviceWrites(collector, {'themeMode': 'system'});
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      expect(rig.count('PATCH'), 2);
      expect(rig.status, AppearanceSyncStatus.synced);
      expect((await rig.account(collector))['themeMode'], 'light');
    });

    test('T-0063-AC2 a second 409 in a row ends offline after exactly 2 '
        'PATCHes, the change kept', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.otherDeviceWrites(collector, {'density': 'compact'});
      // The first PATCH (stale) is held at the server's door while the
      // other device writes again, so the retry is stale too.
      final held = rig.gate.holdNext('PATCH', beforeServer: true);
      final change = rig.appearance.change(reduceMotion: true);
      final first = await held;
      first.release();
      final retry = rig.gate.holdNext('PATCH', beforeServer: true);
      final second = await retry;
      await rig.otherDeviceWrites(collector, {'density': 'comfortable'});
      second.release();
      await change;
      expect(rig.count('PATCH'), 2);
      expect(rig.status, AppearanceSyncStatus.offline);
      expect(rig.shown.reduceMotion, isTrue);
      expect(rig.warnings.last, contains('second version conflict'));
    });
  });

  group('T-0063-AC3 on sign-in, the account wins unless a local change is '
      'not yet synced', () {
    test('T-0063-AC3 nothing changed while signed out: the account replaces '
        'the device copy', () async {
      final rig = await make();
      await rig.settle();
      await rig.signIn(collector);
      await rig.settle();
      expect(rig.shown, _dark);
      expect(rig.count('PATCH'), 0);
    });

    test('T-0063-AC3 a change made signed out goes to the account that '
        'signs in, over its value', () async {
      final rig = await make();
      await rig.appearance.change(
        themeMode: AppearanceThemeMode.light,
        density: AppearanceDensity.compact,
      );
      await rig.signIn(collector);
      await rig.settle();
      expect(
        rig.shown,
        const AppearancePreferences(
          themeMode: AppearanceThemeMode.light,
          density: AppearanceDensity.compact,
        ),
      );
      expect(rig.preferencesTraffic, ['GET', 'PATCH']);
      final account = await rig.account(collector);
      expect(account['themeMode'], 'light');
      expect(account['density'], 'compact');
      expect(rig.status, AppearanceSyncStatus.synced);
    });

    test('T-0063-AC3 a signed-out change sends only its own setting: the '
        'account keeps the rest', () async {
      final rig = await make();
      await rig.appearance.change(reduceMotion: true);
      await rig.signIn(collector);
      await rig.settle();
      expect(rig.shown, _dark.copyWith(reduceMotion: true));
      expect((await rig.account(collector))['themeMode'], 'dark');
    });

    test('T-0063-AC3 sign-out keeps the last values on the device and drops '
        'what was pending', () async {
      final backend = MockBackend(domains: [const IdentityMockDomain()]);
      final rig = await make(signedInAs: collector, backend: backend);
      await rig.settle();
      backend.useScenario('identity.preferences_error');
      await rig.appearance.change(density: AppearanceDensity.compact);
      expect((rig.saved! as Map)['pendingFor'], collector);
      await rig.signOut();
      await rig.settle();
      expect(rig.status, AppearanceSyncStatus.local);
      expect(rig.shown, _dark.copyWith(density: AppearanceDensity.compact));
      expect((rig.saved! as Map)['pending'], isEmpty);
      expect((rig.saved! as Map)['pendingFor'], isNull);
      // u-100 signs in: the account wins, nothing of u-101's is sent.
      backend.useScenario(null);
      await rig.signIn(reader);
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults);
      expect(rig.count('PATCH'), 1, reason: "only u-101's failed one");
      expect((await rig.account(reader))['version'], 0);
    });

    test('T-0063-AC6 a restart while a signed-in change is unsynced sends '
        'it on the next launch, over the account', () async {
      final backend = MockBackend(domains: [const IdentityMockDomain()]);
      final rig = await make(signedInAs: collector, backend: backend);
      await rig.settle();
      backend.useScenario('identity.preferences_error');
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      backend.useScenario(null);
      final again = await rig.relaunch();
      rigs.add(again);
      await again.settle();
      expect(again.shown.themeMode, AppearanceThemeMode.light);
      expect(again.status, AppearanceSyncStatus.synced);
      expect((await again.account(collector))['themeMode'], 'light');
    });

    test("T-0063-AC6 a saved change of another user is dropped on the next "
        "launch, and never sent", () async {
      final backend = MockBackend(domains: [const IdentityMockDomain()]);
      final rig = await make(signedInAs: collector, backend: backend);
      await rig.settle();
      backend.useScenario('identity.preferences_error');
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      backend.useScenario(null);
      // u-100 signs in directly (a switch, no sign-out): u-101's change is
      // dropped, and u-100's account wins.
      await rig.signIn(reader);
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults);
      expect((await rig.account(collector))['themeMode'], 'dark');
      expect((await rig.account(reader))['version'], 0);
    });

    test('T-0063-AC3 a same-user re-sign-in reads the account again', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.otherDeviceWrites(collector, {'density': 'compact'});
      await rig.signIn(collector);
      await rig.settle();
      expect(rig.preferencesTraffic, ['GET', 'GET']);
      expect(rig.shown.density, AppearanceDensity.compact);
    });
  });

  group('T-0063-AC6 a launch against an account that lost the device copy', () {
    test('T-0063-AC6 the mocked backend forgets everything on a relaunch: '
        'the device copy, newer than the account, is sent again and the '
        'account holds it', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      expect((await rig.account(collector))['version'], 1);
      expect((rig.saved! as Map)['seenVersion'], 1);
      expect((rig.saved! as Map)['seenFor'], collector);

      // A new process: a new session on the same directory, a fresh backend
      // (u-101 is back at its dark seed, version 0).
      await rig.quiesce();
      final again = await Rig.create(
        dir: rig.dir,
        backend: MockBackend(domains: [const IdentityMockDomain()]),
      );
      rigs.add(again);
      expect(again.shown.themeMode, AppearanceThemeMode.light);
      await again.settle();
      expect(again.shown.themeMode, AppearanceThemeMode.light);
      expect(again.preferencesTraffic, ['GET', 'PATCH']);
      expect((await again.account(collector))['themeMode'], 'light');
      expect(again.status, AppearanceSyncStatus.synced);
    });

    test('T-0063-AC6 an account that moved on (another device) wins on the '
        'next launch', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      await rig.otherDeviceWrites(collector, {'themeMode': 'system'});
      final again = await rig.relaunch();
      rigs.add(again);
      await again.settle();
      expect(again.shown.themeMode, AppearanceThemeMode.system);
      expect(again.count('PATCH'), 0);
    });

    test("T-0063-AC6 the version seen for another user is not compared: "
        "B's account wins over A's copy", () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.appearance.change(
        themeMode: AppearanceThemeMode.light,
        density: AppearanceDensity.compact,
      );
      await rig.signIn(reader);
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults);
      expect(rig.count('PATCH'), 1);
      expect((rig.saved! as Map)['seenFor'], reader);
      expect((rig.saved! as Map)['seenVersion'], 0);
    });

    test('T-0063-AC6 an account behind the device with the same values sends '
        'nothing', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      await rig.appearance.change(themeMode: AppearanceThemeMode.dark);
      expect((await rig.account(collector))['version'], 2);
      await rig.quiesce();
      final again = await Rig.create(
        dir: rig.dir,
        backend: MockBackend(domains: [const IdentityMockDomain()]),
      );
      rigs.add(again);
      await again.settle();
      expect(again.preferencesTraffic, ['GET']);
      expect(again.shown.themeMode, AppearanceThemeMode.dark);
      expect((again.saved! as Map)['seenVersion'], 0);
    });
  });
}
