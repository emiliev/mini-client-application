// The app-wide appearance (T-0063, ADR-0013): what the user chose, where it
// is kept, and how it follows them across devices. Pure Dart (R15): `app_core`
// maps it onto Flutter's theme, and blocs read it through the ports.
export 'package:mc_appearance/src/appearance.dart' show Appearance;
export 'package:mc_appearance/src/appearance_di_initializer.dart'
    show AppearanceDIInitializer;
export 'package:mc_appearance/src/appearance_ports.dart'
    show AppearanceReader, AppearanceSettings;
export 'package:mc_appearance/src/appearance_preferences.dart'
    show
        AppearanceDensity,
        AppearancePreferences,
        AppearanceSetting,
        AppearanceThemeMode;
export 'package:mc_appearance/src/appearance_snapshot.dart'
    show AppearanceSnapshot, AppearanceSyncStatus;
export 'package:mc_appearance/src/appearance_store.dart'
    show appearanceStoreKey, savedAppearance;
