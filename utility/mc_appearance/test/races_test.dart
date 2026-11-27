// The session races (T-0063-AC6): a user switch during a write or a read,
// in both orders, with held requests and no timers. A's choice never shows
// for B, and never reaches B's account.
import 'package:mc_appearance/mc_appearance.dart';
import 'package:test/test.dart';

import 'rig.dart';

void main() {
  final rigs = <Rig>[];
  Future<Rig> make({String? signedInAs}) async {
    final rig = await Rig.create(signedInAs: signedInAs);
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

  group('T-0063-AC6 a user switch during a PATCH (the epoch pin)', () {
    test('T-0063-AC6 order 1: B signs in before the PATCH leaves: it never '
        "reaches the server, and B sees B's account", () async {
      final rig = await make(signedInAs: reader);
      await rig.settle();
      final change = rig.appearance.change(themeMode: AppearanceThemeMode.dark);
      // Same turn: Dio has not run its first interceptor yet (F-0050 §1).
      final switched = rig.signIn(collector);
      await change;
      await switched;
      await rig.settle();
      expect(rig.preferencesTraffic, ['GET', 'GET'], reason: 'no PATCH left');
      expect((await rig.account(reader))['version'], 0);
      expect((await rig.account(reader))['themeMode'], 'system');
      expect((await rig.account(collector))['version'], 0);
      // B's account (dark): the shown value is B's, not A's dark choice
      // (here the same value; the next test tells them apart).
      expect(rig.shown.themeMode, AppearanceThemeMode.dark);
      expect(rig.status, AppearanceSyncStatus.synced);
      expect((rig.saved! as Map)['pending'], isEmpty);
    });

    test("T-0063-AC6 order 1 with a value B's account does not hold: B sees "
        "B's value", () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      final change = rig.appearance.change(
        themeMode: AppearanceThemeMode.light,
      );
      final switched = rig.signIn(reader);
      await change;
      await switched;
      await rig.settle();
      expect(rig.count('PATCH'), 0);
      expect(rig.shown.themeMode, AppearanceThemeMode.system);
      expect((await rig.account(reader))['themeMode'], 'system');
      expect((await rig.account(collector))['themeMode'], 'dark');
    });

    test("T-0063-AC6 order 2: A's PATCH is out when B signs in; its late "
        "answer changes nothing, and B sees B's account", () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      final held = rig.gate.holdNext('PATCH');
      final change = rig.appearance.change(
        themeMode: AppearanceThemeMode.light,
      );
      final out = await held;
      expect(out.authorization, contains(collector), reason: "A's bearer");
      await rig.signIn(reader);
      await rig.settle();
      expect(rig.shown.themeMode, AppearanceThemeMode.system, reason: "B's");
      out.release();
      await change;
      await rig.settle();
      expect(rig.shown.themeMode, AppearanceThemeMode.system);
      expect(rig.status, AppearanceSyncStatus.synced);
      // A's write reached A's account only.
      expect((await rig.account(collector))['themeMode'], 'light');
      expect((await rig.account(reader))['version'], 0);
      expect(rig.count('PATCH'), 1);
    });

    test("T-0063-AC6 order 2, held before the server: A's PATCH, sent with "
        "A's bearer, lands in A's account after B signed in, and B's view "
        'is unchanged', () async {
      final rig = await make(signedInAs: collector);
      await rig.settle();
      final held = rig.gate.holdNext('PATCH', beforeServer: true);
      final change = rig.appearance.change(reduceMotion: true);
      final out = await held;
      await rig.signIn(reader);
      await rig.settle();
      out.release();
      await change;
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults);
      expect((await rig.account(collector))['reduceMotion'], true);
      expect((await rig.account(reader))['reduceMotion'], false);
    });

    test('T-0063-AC6 a sign-out while a PATCH is out keeps the values and '
        'ignores its answer', () async {
      final rig = await make(signedInAs: reader);
      await rig.settle();
      final held = rig.gate.holdNext('PATCH');
      final change = rig.appearance.change(density: AppearanceDensity.compact);
      final out = await held;
      await rig.signOut();
      await rig.settle();
      out.release();
      await change;
      await rig.settle();
      expect(rig.status, AppearanceSyncStatus.local);
      expect(rig.shown.density, AppearanceDensity.compact);
      expect((rig.saved! as Map)['pending'], isEmpty);
    });
  });

  group('T-0063-AC6 a user switch during the GET', () {
    test("T-0063-AC6 A's GET answers after B signed in: dropped, B's "
        'account shows', () async {
      final rig = await make();
      await rig.settle();
      final held = rig.gate.holdNext('GET');
      await rig.signIn(collector);
      final out = await held;
      await rig.signIn(reader);
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults);
      expect(rig.status, AppearanceSyncStatus.synced);
      out.release();
      await rig.settle();
      expect(rig.shown, AppearancePreferences.defaults, reason: "not A's dark");
      expect(rig.status, AppearanceSyncStatus.synced);
    });

    test("T-0063-AC6 B's GET answers before A's: A's late answer still "
        'changes nothing', () async {
      final rig = await make();
      await rig.settle();
      final heldA = rig.gate.holdNext('GET');
      await rig.signIn(reader);
      final outA = await heldA;
      final heldB = rig.gate.holdNext('GET');
      await rig.signIn(collector);
      final outB = await heldB;
      outB.release();
      await rig.settle();
      expect(rig.shown.themeMode, AppearanceThemeMode.dark, reason: "B's");
      outA.release();
      await rig.settle();
      expect(rig.shown.themeMode, AppearanceThemeMode.dark);
      expect(rig.status, AppearanceSyncStatus.synced);
    });

    test('T-0063-AC6 a change made while the sign-in GET is out is sent '
        'after it, on the version it read', () async {
      final rig = await make();
      await rig.settle();
      final held = rig.gate.holdNext('GET');
      await rig.signIn(collector);
      final out = await held;
      final change = rig.appearance.change(density: AppearanceDensity.compact);
      expect(rig.status, AppearanceSyncStatus.pending);
      out.release();
      await change;
      await rig.settle();
      expect(rig.preferencesTraffic, ['GET', 'PATCH']);
      expect(
        rig.shown,
        const AppearancePreferences(
          themeMode: AppearanceThemeMode.dark,
          density: AppearanceDensity.compact,
        ),
      );
      expect((await rig.account(collector))['density'], 'compact');
    });

    test('T-0063-AC6 a change made after a session change that the stream '
        'has not delivered yet belongs to the new session: its account is '
        'read before anything is written to it', () async {
      final rig = await make(signedInAs: reader);
      await rig.settle();
      // The reader's account moves to version 1, the collector's stays at 0:
      // a write sent on the reader's version would be a conflict.
      await rig.appearance.change(density: AppearanceDensity.compact);
      final before = rig.preferencesTraffic.length;
      // The session switches; its events are still queued when the user
      // changes something in the same turn.
      final switched = rig.signIn(collector);
      final change = rig.appearance.change(reduceMotion: true);
      await switched;
      await change;
      await rig.settle();
      expect(
        rig.preferencesTraffic.sublist(before),
        ['GET', 'PATCH'],
        reason: "the collector's account is read first",
      );
      final account = await rig.account(collector);
      expect(account['reduceMotion'], true);
      expect(account['version'], 1);
      expect((await rig.account(reader))['version'], 1);
    });
  });
}
