import 'package:auth_signin/src/domain/model/sign_in_failure.dart';
import 'package:auth_signin/src/domain/model/sign_in_reason.dart';
import 'package:auth_signin/src/l10n/auth_signin_l10n.dart';
import 'package:auth_signin/src/presentation/form/auth_signin_form.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// What the user reads for a failed request, from the shared error copy.
String failureMessage(ApiFailure failure, McL10nCoreL10n core) =>
    switch (failure) {
      ApiTimeout() => core.errorTimeout,
      ApiOffline() => core.errorNetwork,
      ApiServer() => core.errorServer,
      _ => core.errorGeneric,
    };

/// The form-level error for [failure].
String signInFailureMessage(
  SignInFailure failure,
  AuthSignInL10n l10n,
  McL10nCoreL10n core,
) => switch (failure) {
  InvalidCredentials() => l10n.authSignInInvalidCredentials,
  SignInUnavailable(:final cause) => l10n.authSignInFailed(
    failureMessage(cause, core),
  ),
};

/// The line above the form: what the sign-in is for.
String reasonMessage(SignInReason? reason, AuthSignInL10n l10n) =>
    switch (reason) {
      null => l10n.authSignInIntro,
      SignInReason.favourites => l10n.authSignInReasonFavourites,
      SignInReason.readingLists => l10n.authSignInReasonReadingLists,
      SignInReason.cart => l10n.authSignInReasonCart,
      SignInReason.triviaResults => l10n.authSignInReasonTriviaResults,
      SignInReason.appearanceSync => l10n.authSignInReasonAppearanceSync,
    };

/// The message under [field] for [error] (the kit reports codes only).
String fieldErrorMessage(String field, FieldError error, AuthSignInL10n l10n) =>
    switch (field) {
      SignInFields.email =>
        error.code == ValidationCode.required
            ? l10n.authSignInEmailRequired
            : l10n.authSignInEmailInvalid,
      _ => l10n.authSignInPasswordRequired,
    };
