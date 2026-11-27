import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The screen names of the flow's two pages: their `McFlowPage` names, which
/// `AnalyticsFlowObserver` tracks. The first equals the app route's name
/// (`/settings/appearance` is `settings_appearance`), so it is not tracked
/// twice (ADR-0012).
const String settingsAppearanceScreen = 'settings_appearance';
const String settingsAppearanceAboutScreen = 'settings_appearance_about';

/// A setting was changed by the user (not by a sync).
const String settingsChangedEvent = 'settings_changed';

/// What was changed: the analytics `setting` parameter. Every ST feature
/// names its own settings; `reset` is "every setting of the screen back to
/// its default".
enum TrackedSetting {
  themeMode('theme_mode'),
  density('density'),
  reduceMotion('reduce_motion'),
  reset('reset');

  const TrackedSetting(this.wireName);

  final String wireName;
}

/// The settings screen's analytics vocabulary over the blocs' pure-Dart port
/// (`AnalyticsTracker`, R15, ADR-0012): the event and its parameters are
/// spelled once, here.
extension SettingsTracking on AnalyticsTracker {
  /// `settings_changed` with `setting` and `value` (the new value as the
  /// identity contract spells it: `dark`, `compact`, `true`; `defaults` for
  /// a reset).
  void settingChanged(TrackedSetting setting, String value) => trackEvent(
    settingsChangedEvent,
    {'setting': setting.wireName, 'value': value},
  );

  /// The theme mode was chosen.
  void themeModeChanged(AppearanceThemeMode mode) =>
      settingChanged(TrackedSetting.themeMode, mode.wire);

  /// The density was chosen.
  void densityChanged(AppearanceDensity density) =>
      settingChanged(TrackedSetting.density, density.wire);

  /// Reduce motion was switched.
  void reduceMotionChanged({required bool on}) =>
      settingChanged(TrackedSetting.reduceMotion, '$on');

  /// Everything went back to the defaults.
  void resetToDefaults() => settingChanged(TrackedSetting.reset, 'defaults');
}
