import 'package:mc_forms/mc_forms.dart';

/// The form's field names (`mc_forms`).
abstract final class SignInFields {
  static const String email = 'email';
  static const String password = 'password';
}

/// The shape of an email address: something, an `@`, something, a dot and
/// something. The backend is the judge of whether the account exists; this
/// only catches a typo before a request is spent on it.
final RegExp emailShape = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');

/// Applies [rule] to the trimmed text, as the sign-in sends the email.
Validator<String> _trimmed(Validator<String> rule) =>
    (value) => rule(value?.trim());

/// The two fields and their rules. The password is only required: the
/// backend's rules for a password are not the form's business, and a
/// shorter-than-expected one is answered by the same "wrong credentials".
List<FieldSpec> signInFields() => [
  FieldDef<String>(
    SignInFields.email,
    initial: '',
    validators: [Validators.required<String>(), _trimmed(_shape)],
  ),
  FieldDef<String>(
    SignInFields.password,
    initial: '',
    validators: [Validators.required<String>()],
  ),
];

final Validator<String> _shape = Validators.pattern(emailShape);
