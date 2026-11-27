part of 'auth_signin_bloc.dart';

/// What the form page asks for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories.
sealed class AuthSignInEvent {
  const AuthSignInEvent();

  const factory AuthSignInEvent.emailChanged(String email) = _EmailChanged;

  const factory AuthSignInEvent.passwordChanged(String password) =
      _PasswordChanged;

  /// A text field lost focus: its error may show.
  const factory AuthSignInEvent.touched(String field) = _Touched;

  /// "Use a demo account": fills both fields.
  const factory AuthSignInEvent.useDemoAccount(DemoAccount account) =
      _UseDemoAccount;

  /// Sign in, and Try again after a failure.
  const factory AuthSignInEvent.submit() = _Submit;

  /// "Not now": the flow ends as cancelled.
  const factory AuthSignInEvent.notNow() = _NotNow;
}

final class _EmailChanged extends AuthSignInEvent {
  const _EmailChanged(this.email);

  final String email;
}

final class _PasswordChanged extends AuthSignInEvent {
  const _PasswordChanged(this.password);

  final String password;
}

final class _Touched extends AuthSignInEvent {
  const _Touched(this.field);

  final String field;
}

final class _UseDemoAccount extends AuthSignInEvent {
  const _UseDemoAccount(this.account);

  final DemoAccount account;
}

final class _Submit extends AuthSignInEvent {
  const _Submit();
}

final class _NotNow extends AuthSignInEvent {
  const _NotNow();
}

/// Internal: the form controller reported a new state (outside any handler;
/// an event brings it back into the bloc, so only a handler emits).
final class _FormChanged extends AuthSignInEvent {
  const _FormChanged(this.form);

  final McFormState form;
}
