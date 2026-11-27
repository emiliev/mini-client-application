part of 'appearance_bloc.dart';

/// What the appearance settings ask for (Tide's sealed events).
sealed class AppearanceEvent {
  const AppearanceEvent();

  /// The screen opened: show the appearance and follow it.
  const factory AppearanceEvent.load() = _Load;

  /// A theme mode was chosen.
  const factory AppearanceEvent.setThemeMode(AppearanceThemeMode mode) =
      _SetThemeMode;

  /// A density was chosen.
  const factory AppearanceEvent.setDensity(AppearanceDensity density) =
      _SetDensity;

  /// Reduce motion was switched on or off.
  const factory AppearanceEvent.setReduceMotion({required bool on}) =
      _SetReduceMotion;

  /// "Reset to defaults" was confirmed (the page asked first).
  const factory AppearanceEvent.reset() = _Reset;

  /// Retry: after a failed save, or a sync that failed.
  const factory AppearanceEvent.retry() = _Retry;

  /// Signed out, "Sync across devices" was tapped.
  const factory AppearanceEvent.syncAcrossDevices() = _SyncAcrossDevices;

  /// "About themes" was tapped: the explainer opens in the flow.
  const factory AppearanceEvent.openAbout() = _OpenAbout;
}

final class _Load extends AppearanceEvent {
  const _Load();
}

final class _SetThemeMode extends AppearanceEvent {
  const _SetThemeMode(this.mode);

  final AppearanceThemeMode mode;
}

final class _SetDensity extends AppearanceEvent {
  const _SetDensity(this.density);

  final AppearanceDensity density;
}

final class _SetReduceMotion extends AppearanceEvent {
  const _SetReduceMotion({required this.on});

  final bool on;
}

final class _Reset extends AppearanceEvent {
  const _Reset();
}

final class _Retry extends AppearanceEvent {
  const _Retry();
}

final class _SyncAcrossDevices extends AppearanceEvent {
  const _SyncAcrossDevices();
}

final class _OpenAbout extends AppearanceEvent {
  const _OpenAbout();
}

/// Internal: the appearance changed (a change, a sync, a session). The
/// state is read from the appearance itself, which is always current.
final class _Changed extends AppearanceEvent {
  const _Changed();
}
