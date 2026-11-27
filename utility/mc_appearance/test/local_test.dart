// Signed out, the device's copy is the truth: changes apply at once, are
// kept before the call returns, and survive a restart (T-0063-AC6).
import 'dart:io';

import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_storage/mc_storage.dart';
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

  test('T-0063-AC1 a new install shows the defaults, kept locally, and '
      'sends nothing', () async {
    final rig = await make();
    await rig.settle();
    expect(rig.shown, AppearancePreferences.defaults);
    expect(rig.status, AppearanceSyncStatus.local);
    expect(rig.appearance.snapshot.saveFailure, isNull);
    expect(rig.preferencesTraffic, isEmpty);
    expect(rig.saved, isNull, reason: 'nothing to save yet');
  });

  test('T-0063-AC6 signed out, a change applies at once, is saved before '
      'the call returns, and is announced once', () async {
    final rig = await make();
    final seen = <AppearanceSnapshot>[];
    final sub = rig.appearance.changes.listen(seen.add);
    final done = rig.appearance.change(themeMode: AppearanceThemeMode.dark);
    // Synchronously: shown and on disk.
    expect(rig.shown.themeMode, AppearanceThemeMode.dark);
    expect((rig.saved! as Map)['themeMode'], 'dark');
    expect((rig.saved! as Map)['pending'], ['themeMode']);
    expect((rig.saved! as Map)['pendingFor'], isNull);
    await done;
    await rig.settle();
    expect(seen, [
      const AppearanceSnapshot(
        preferences: AppearancePreferences(
          themeMode: AppearanceThemeMode.dark,
        ),
        status: AppearanceSyncStatus.local,
      ),
    ]);
    expect(rig.preferencesTraffic, isEmpty);
    await sub.cancel();
  });

  test('T-0063-AC6 a change that changes nothing saves and announces '
      'nothing', () async {
    final rig = await make();
    final seen = <AppearanceSnapshot>[];
    final sub = rig.appearance.changes.listen(seen.add);
    await rig.appearance.change(themeMode: AppearanceThemeMode.system);
    await rig.appearance.change();
    await rig.appearance.reset();
    await rig.settle();
    expect(seen, isEmpty);
    expect(rig.saved, isNull);
    await sub.cancel();
  });

  test('T-0063-AC6 signed out, the choice survives a restart', () async {
    final rig = await make();
    await rig.appearance.change(
      themeMode: AppearanceThemeMode.dark,
      density: AppearanceDensity.compact,
      reduceMotion: true,
    );
    final again = await rig.relaunch();
    rigs.add(again);
    await again.settle();
    expect(
      again.shown,
      const AppearancePreferences(
        themeMode: AppearanceThemeMode.dark,
        density: AppearanceDensity.compact,
        reduceMotion: true,
      ),
    );
    expect(again.status, AppearanceSyncStatus.local);
    expect(again.preferencesTraffic, isEmpty);
  });

  test('T-0063-AC3 reset restores the defaults as one change', () async {
    final rig = await make();
    await rig.appearance.change(
      themeMode: AppearanceThemeMode.light,
      reduceMotion: true,
    );
    await rig.appearance.reset();
    expect(rig.shown, AppearancePreferences.defaults);
    expect((rig.saved! as Map)['themeMode'], 'system');
    expect((rig.saved! as Map)['reduceMotion'], false);
  });

  test('T-0063-AC6 an unreadable saved copy starts from the defaults and '
      'warns, and the next change replaces it', () async {
    final dir = Directory.systemTemp.createTempSync('mc_app_');
    FileStore(dir).writeSync(appearanceStoreKey, {'themeMode': 'purple'});
    final rig = await Rig.create(dir: dir);
    rigs.add(rig);
    expect(rig.shown, AppearancePreferences.defaults);
    expect(rig.warnings.single, contains('unreadable'));
    await rig.appearance.change(themeMode: AppearanceThemeMode.light);
    expect((rig.saved! as Map)['themeMode'], 'light');
  });

  test('T-0063-AC6 a save that fails keeps the change in use, says so, and '
      'retry saves it once the device can write again', () async {
    final rig = await make();
    // The value's file becomes a directory: every save fails.
    await rig.appearance.change(density: AppearanceDensity.compact);
    final file = rig.dir.listSync().whereType<File>().firstWhere(
      (f) => f.path.endsWith('.json') && _isAppearance(f),
    );
    file.deleteSync();
    Directory(file.path).createSync();

    await rig.appearance.change(themeMode: AppearanceThemeMode.dark);
    expect(rig.shown.themeMode, AppearanceThemeMode.dark, reason: 'applied');
    final failure = rig.appearance.snapshot.saveFailure;
    expect(failure, isA<StorageFailure>());
    expect(rig.warnings.last, contains('could not keep'));

    // Retry while still failing: still failing.
    await rig.appearance.retry();
    expect(rig.appearance.snapshot.saveFailure, isNotNull);

    Directory(file.path).deleteSync();
    await rig.appearance.retry();
    expect(rig.appearance.snapshot.saveFailure, isNull);
    expect((rig.saved! as Map)['themeMode'], 'dark');
    expect((rig.saved! as Map)['density'], 'compact');
  });

  test('T-0063-AC6 after a failed save, the next change saves even when it '
      'brings the record back to the last one saved', () async {
    final rig = await make();
    await rig.appearance.change(themeMode: AppearanceThemeMode.dark);
    final file = rig.dir.listSync().whereType<File>().firstWhere(_isAppearance);
    file.deleteSync();
    Directory(file.path).createSync();
    await rig.appearance.change(themeMode: AppearanceThemeMode.light);
    expect(rig.appearance.snapshot.saveFailure, isNotNull);
    Directory(file.path).deleteSync();
    // Back to what was saved before the failure: still written.
    await rig.appearance.change(themeMode: AppearanceThemeMode.dark);
    expect(rig.appearance.snapshot.saveFailure, isNull);
    expect((rig.saved! as Map)['themeMode'], 'dark');
  });

  test('T-0063-AC6 after dispose a change does nothing', () async {
    final rig = await make();
    await rig.appearance.dispose();
    await rig.appearance.change(themeMode: AppearanceThemeMode.dark);
    await rig.appearance.retry();
    expect(rig.shown, AppearancePreferences.defaults);
    expect(rig.saved, isNull);
  });
  test(
    'T-0063-AC7 without followAccount it keeps the device copy only: '
    'signed in, nothing is read or sent and the status stays local',
    () async {
      final rig = await Rig.create(signedInAs: collector, followAccount: false);
      rigs.add(rig);
      await rig.settle();
      await rig.appearance.change(themeMode: AppearanceThemeMode.light);
      await rig.signIn(reader);
      await rig.appearance.retry();
      await rig.settle();
      expect(rig.preferencesTraffic, isEmpty);
      expect(rig.status, AppearanceSyncStatus.local);
      expect(rig.shown.themeMode, AppearanceThemeMode.light);
      expect((rig.saved! as Map)['pendingFor'], isNull);
    },
  );
}

bool _isAppearance(FileSystemEntity f) {
  try {
    final text = File(f.path).readAsStringSync();
    return text.contains('"pending"');
  } on FileSystemException {
    return false;
  }
}
