/// The theme the app uses: the platform's (`system`), or always light or
/// dark. [wire] is the identity preferences' value (`mc_fixtures_identity`
/// CONTRACT.md).
enum AppearanceThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppearanceThemeMode(this.wire);

  final String wire;

  /// The mode [value] names, or null when it names none.
  static AppearanceThemeMode? fromWire(Object? value) =>
      _byWire(values, (v) => v.wire, value);
}

/// How much space the app gives its controls (ADR-0013: `ThemeData`'s visual
/// density, and the spacing a screen derives from it).
enum AppearanceDensity {
  comfortable('comfortable'),
  compact('compact');

  const AppearanceDensity(this.wire);

  final String wire;

  /// The density [value] names, or null when it names none.
  static AppearanceDensity? fromWire(Object? value) =>
      _byWire(values, (v) => v.wire, value);
}

/// One of the three settings: the unit a local change, a pending sync and a
/// `PATCH` key are counted in. [wireKey] is its key on the wire and on disk.
enum AppearanceSetting {
  themeMode('themeMode'),
  density('density'),
  reduceMotion('reduceMotion');

  const AppearanceSetting(this.wireKey);

  final String wireKey;

  /// The setting [key] names, or null when it names none.
  static AppearanceSetting? fromWireKey(Object? key) {
    for (final setting in values) {
      if (setting.wireKey == key) {
        return setting;
      }
    }
    return null;
  }
}

T? _byWire<T>(List<T> values, String Function(T) wire, Object? value) {
  for (final v in values) {
    if (wire(v) == value) {
      return v;
    }
  }
  return null;
}

/// What the user chose: an immutable value. [defaults] is what a new install
/// and a user who never saved see (System, Comfortable, Reduce motion off).
final class AppearancePreferences {
  const AppearancePreferences({
    this.themeMode = AppearanceThemeMode.system,
    this.density = AppearanceDensity.comfortable,
    this.reduceMotion = false,
  });

  static const AppearancePreferences defaults = AppearancePreferences();

  final AppearanceThemeMode themeMode;
  final AppearanceDensity density;

  /// The app's own animations are off (ADR-0013), on top of the platform's
  /// setting.
  final bool reduceMotion;

  AppearancePreferences copyWith({
    AppearanceThemeMode? themeMode,
    AppearanceDensity? density,
    bool? reduceMotion,
  }) => AppearancePreferences(
    themeMode: themeMode ?? this.themeMode,
    density: density ?? this.density,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  /// [setting]'s value as the wire spells it.
  Object wireValue(AppearanceSetting setting) => switch (setting) {
    AppearanceSetting.themeMode => themeMode.wire,
    AppearanceSetting.density => density.wire,
    AppearanceSetting.reduceMotion => reduceMotion,
  };

  /// These preferences, except that [settings] take [other]'s values.
  AppearancePreferences overlay(
    AppearancePreferences other,
    Iterable<AppearanceSetting> settings,
  ) {
    final keys = settings.toSet();
    return AppearancePreferences(
      themeMode: keys.contains(AppearanceSetting.themeMode)
          ? other.themeMode
          : themeMode,
      density: keys.contains(AppearanceSetting.density)
          ? other.density
          : density,
      reduceMotion: keys.contains(AppearanceSetting.reduceMotion)
          ? other.reduceMotion
          : reduceMotion,
    );
  }

  /// The settings whose values differ from [other]'s.
  Set<AppearanceSetting> differencesFrom(AppearancePreferences other) => {
    for (final setting in AppearanceSetting.values)
      if (wireValue(setting) != other.wireValue(setting)) setting,
  };

  /// The wire keys and values of [settings] (all three by default).
  Map<String, Object> toWire([Iterable<AppearanceSetting>? settings]) => {
    for (final setting in settings ?? AppearanceSetting.values)
      setting.wireKey: wireValue(setting),
  };

  /// The preferences of a wire object (a `GET` body, a `PATCH` answer, a
  /// `409`'s `current`, or the device's saved copy), or null when any of
  /// the three keys is missing or not one of its values: a body that cannot
  /// be read whole is not used at all.
  static AppearancePreferences? fromWire(Object? json) {
    if (json is! Map) {
      return null;
    }
    final themeMode = AppearanceThemeMode.fromWire(json['themeMode']);
    final density = AppearanceDensity.fromWire(json['density']);
    final reduceMotion = json['reduceMotion'];
    if (themeMode == null || density == null || reduceMotion is! bool) {
      return null;
    }
    return AppearancePreferences(
      themeMode: themeMode,
      density: density,
      reduceMotion: reduceMotion,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppearancePreferences &&
      other.themeMode == themeMode &&
      other.density == density &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(themeMode, density, reduceMotion);

  @override
  String toString() =>
      'AppearancePreferences(${themeMode.wire}, ${density.wire}, '
      'reduceMotion: $reduceMotion)';
}
