part of 'settings_home_bloc.dart';

/// What the settings index asks for (Tide's sealed events).
sealed class SettingsHomeEvent {
  const SettingsHomeEvent();

  /// The page opened: show the session and the appearance, and follow them.
  const factory SettingsHomeEvent.load() = _Load;

  /// Signed out, "Sign in" was tapped.
  const factory SettingsHomeEvent.signIn() = _SignIn;

  /// Signed in, "Sign out" was tapped.
  const factory SettingsHomeEvent.signOut() = _SignOut;

  /// The Appearance row was tapped.
  const factory SettingsHomeEvent.openAppearance() = _OpenAppearance;
}

final class _Load extends SettingsHomeEvent {
  const _Load();
}

final class _SignIn extends SettingsHomeEvent {
  const _SignIn();
}

final class _SignOut extends SettingsHomeEvent {
  const _SignOut();
}

final class _OpenAppearance extends SettingsHomeEvent {
  const _OpenAppearance();
}

/// Internal: the session changed (a sign-in, a sign-out, a user switch).
final class _SessionChanged extends SettingsHomeEvent {
  const _SessionChanged();
}

/// Internal: the appearance changed. The state is read from the appearance
/// itself, which is always current.
final class _AppearanceChanged extends SettingsHomeEvent {
  const _AppearanceChanged();
}
