// The value types and the device record, solitary (ADR-0010: utilities get
// unit tests).
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_appearance/src/appearance_store.dart';
import 'package:mc_appearance/src/preferences_api.dart';
import 'package:test/test.dart';

void main() {
  const dark = AppearancePreferences(themeMode: AppearanceThemeMode.dark);
  const compact = AppearancePreferences(density: AppearanceDensity.compact);

  test('T-0063-AC1 the defaults are System, Comfortable and Reduce motion '
      'off', () {
    const sut = AppearancePreferences.defaults;
    expect(sut.themeMode, AppearanceThemeMode.system);
    expect(sut.density, AppearanceDensity.comfortable);
    expect(sut.reduceMotion, isFalse);
    expect(sut, const AppearancePreferences());
  });

  test('T-0063-AC1 the wire spells every value as the identity contract '
      'does', () {
    expect(
      [for (final m in AppearanceThemeMode.values) m.wire],
      [
        'system',
        'light',
        'dark',
      ],
    );
    expect(
      [for (final d in AppearanceDensity.values) d.wire],
      [
        'comfortable',
        'compact',
      ],
    );
    expect(
      [for (final s in AppearanceSetting.values) s.wireKey],
      [
        'themeMode',
        'density',
        'reduceMotion',
      ],
    );
    expect(
      const AppearancePreferences(
        themeMode: AppearanceThemeMode.light,
        density: AppearanceDensity.compact,
        reduceMotion: true,
      ).toWire(),
      {'themeMode': 'light', 'density': 'compact', 'reduceMotion': true},
    );
    expect(dark.toWire([AppearanceSetting.themeMode]), {'themeMode': 'dark'});
  });

  test('T-0063-AC1 fromWire reads a whole object and refuses a partial or '
      'wrong one', () {
    expect(
      AppearancePreferences.fromWire({
        'themeMode': 'dark',
        'density': 'compact',
        'reduceMotion': true,
        'version': 3,
      }),
      const AppearancePreferences(
        themeMode: AppearanceThemeMode.dark,
        density: AppearanceDensity.compact,
        reduceMotion: true,
      ),
    );
    for (final bad in <Object?>[
      null,
      'dark',
      <String, Object?>{},
      {'themeMode': 'dark', 'density': 'compact'},
      {'themeMode': 'Dark', 'density': 'compact', 'reduceMotion': false},
      {'themeMode': 'dark', 'density': 'tight', 'reduceMotion': false},
      {'themeMode': 'dark', 'density': 'compact', 'reduceMotion': 'no'},
    ]) {
      expect(AppearancePreferences.fromWire(bad), isNull, reason: '$bad');
    }
    expect(AppearanceThemeMode.fromWire('light'), AppearanceThemeMode.light);
    expect(AppearanceThemeMode.fromWire(1), isNull);
    expect(AppearanceDensity.fromWire('compact'), AppearanceDensity.compact);
    expect(AppearanceSetting.fromWireKey('density'), AppearanceSetting.density);
    expect(AppearanceSetting.fromWireKey('version'), isNull);
  });

  test('T-0063-AC2 overlay takes only the named settings from the other '
      'side', () {
    final account = dark.copyWith(reduceMotion: true);
    expect(
      account.overlay(compact, {AppearanceSetting.density}),
      const AppearancePreferences(
        themeMode: AppearanceThemeMode.dark,
        density: AppearanceDensity.compact,
        reduceMotion: true,
      ),
    );
    expect(account.overlay(compact, const {}), account);
    expect(
      account.overlay(compact, AppearanceSetting.values),
      compact,
      reason: 'every setting taken',
    );
    expect(
      account.overlay(compact, {AppearanceSetting.reduceMotion}),
      dark,
    );
    expect(
      account.overlay(compact, {AppearanceSetting.themeMode}),
      const AppearancePreferences(reduceMotion: true),
    );
  });

  test('T-0063-AC2 differencesFrom names exactly the settings that differ', () {
    expect(dark.differencesFrom(dark), isEmpty);
    expect(dark.differencesFrom(AppearancePreferences.defaults), {
      AppearanceSetting.themeMode,
    });
    expect(
      dark.copyWith(reduceMotion: true).differencesFrom(compact),
      AppearanceSetting.values.toSet(),
    );
  });

  test('T-0063-AC1 equality, hash and copyWith', () {
    expect(dark, dark.copyWith());
    expect(dark.hashCode, dark.copyWith().hashCode);
    expect(dark == compact, isFalse);
    expect(
      dark.copyWith(density: AppearanceDensity.compact).density,
      AppearanceDensity.compact,
    );
    expect('$dark', contains('dark'));
    const a = AppearanceSnapshot(
      preferences: AppearancePreferences.defaults,
      status: AppearanceSyncStatus.local,
    );
    expect(
      a,
      const AppearanceSnapshot(
        preferences: AppearancePreferences.defaults,
        status: AppearanceSyncStatus.local,
      ),
    );
    expect(a.hashCode, isA<int>());
    expect(
      a ==
          const AppearanceSnapshot(
            preferences: AppearancePreferences.defaults,
            status: AppearanceSyncStatus.synced,
          ),
      isFalse,
    );
    expect('$a', contains('local'));
  });

  test('T-0063-AC6 the device record keeps the preferences, the pending '
      'settings and their owner, and reads leniently', () {
    final record = AppearanceRecord(
      preferences: dark,
      pending: {AppearanceSetting.reduceMotion, AppearanceSetting.themeMode},
      pendingFor: 'u-101',
    );
    final json = record.toJson();
    expect(json, {
      'themeMode': 'dark',
      'density': 'comfortable',
      'reduceMotion': false,
      // In a fixed order, whatever the set's.
      'pending': ['themeMode', 'reduceMotion'],
      'pendingFor': 'u-101',
    });
    final back = AppearanceRecord.fromJson(json)!;
    expect(back.preferences, dark);
    expect(back.pending, record.pending);
    expect(back.pendingFor, 'u-101');

    final lenient = AppearanceRecord.fromJson({
      ...dark.toWire(),
      'pending': ['themeMode', 'version', 7],
      'pendingFor': '',
    })!;
    expect(lenient.pending, {AppearanceSetting.themeMode});
    expect(lenient.pendingFor, isNull);
    expect(AppearanceRecord.fromJson(dark.toWire())!.pending, isEmpty);
    expect(AppearanceRecord.fromJson({'pending': <String>[]}), isNull);
    expect(AppearanceRecord.fromJson('dark'), isNull);
  });

  test('T-0063-AC2 a preferences copy needs the object and an int version', () {
    final copy = PreferencesCopy.parse({...dark.toWire(), 'version': 4});
    expect(copy.preferences, dark);
    expect(copy.version, 4);
    expect(
      PreferencesCopy.parse(
        '{"themeMode":"light","density":"compact",'
        '"reduceMotion":true,"version":1}',
      ).version,
      1,
    );
    expect(() => PreferencesCopy.parse(dark.toWire()), throwsFormatException);
    expect(
      () => PreferencesCopy.parse({...dark.toWire(), 'version': '1'}),
      throwsFormatException,
    );
    expect(() => PreferencesCopy.parse(null), throwsFormatException);
  });
}
