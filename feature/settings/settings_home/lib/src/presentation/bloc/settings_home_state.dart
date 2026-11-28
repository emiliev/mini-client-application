part of 'settings_home_bloc.dart';

/// The settings index's state (Tide's shape, R16). It has no failure state:
/// nothing on the page can fail to show (a profile that cannot be read
/// leaves the user named by id).
@Freezed(copyWith: false)
sealed class SettingsHomeState with _$SettingsHomeState {
  /// Before the page has read the session.
  const factory SettingsHomeState.loading() = _Loading;

  /// [busy]: the app is signing someone in or out for this page.
  const factory SettingsHomeState.ready({
    required AccountView account,
    required AppearanceThemeMode themeMode,
    required AboutInfo about,
    @Default(false) bool busy,
  }) = _Ready;
}
