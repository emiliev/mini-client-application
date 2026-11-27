import 'package:mc_appearance/src/appearance_preferences.dart';
import 'package:mc_appearance/src/appearance_snapshot.dart';

/// The read side: what the app shell (`McApp`) and any feature that adapts
/// to the appearance see.
abstract interface class AppearanceReader {
  /// The preferences in use now, and how they stand. Synchronous.
  AppearanceSnapshot get snapshot;

  /// Every later snapshot, as it changes (a broadcast stream without
  /// replay: read [snapshot] for the current value). Equal snapshots are
  /// not repeated.
  Stream<AppearanceSnapshot> get changes;
}

/// The write side: the settings feature.
///
/// **A change is never blocked.** It applies at once, everywhere, and is
/// kept on the device before the call returns; a failed sync only changes
/// the status. The returned future completes when the sync it started has
/// ended (tests wait on it; the app does not need to).
abstract interface class AppearanceSettings implements AppearanceReader {
  /// Changes the given settings and leaves the others as they are. A call
  /// that changes nothing does nothing (no save, no request).
  Future<void> change({
    AppearanceThemeMode? themeMode,
    AppearanceDensity? density,
    bool? reduceMotion,
  });

  /// Back to [AppearancePreferences.defaults], as one change.
  Future<void> reset();

  /// After a failure: saves on the device again if the last save failed,
  /// and, when signed in, reads the account's copy again and sends what is
  /// still unsynced.
  Future<void> retry();
}
