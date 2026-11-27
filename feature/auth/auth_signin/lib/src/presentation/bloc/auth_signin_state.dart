part of 'auth_signin_bloc.dart';

/// The form as the page shows it: both fields (value, error, touched) and
/// the submit's status, all in [form] (`mc_forms`).
final class AuthSignInState {
  const AuthSignInState(this.form);

  final McFormState form;

  /// A request is on its way, or the sign-in succeeded and the page has not
  /// left yet: the page is busy either way, so nothing can be sent twice.
  bool get isBusy =>
      form.isSubmitting || form.submitStatus == SubmitStatus.succeeded;

  /// Why the last submit failed, or null (nothing was submitted, it is
  /// running, it succeeded, or an edit cleared the failure).
  SignInFailure? get failure {
    final cause = form.submitFailure;
    return form.submitStatus == SubmitStatus.failed && cause != null
        ? SignInFailure.of(cause)
        : null;
  }
}
