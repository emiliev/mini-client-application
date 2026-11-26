import 'package:mc_api_errors/mc_api_errors.dart';

/// A part of a list the backend validates and the user can change.
/// [wireName] is the `parameter` its `400` names (`mc_fixtures_library`
/// CONTRACT.md, "Validation"). The visibility is not one: the editor only
/// ever sends one of the two values the contract allows, so a `400` for it
/// is an ordinary failure.
enum ListField {
  name('name'),
  description('description'),
  comics('comicIds');

  const ListField(this.wireName);

  final String wireName;

  /// The field a `400` names, or null for one the editor has no field for
  /// (`parameter: "body"`).
  static ListField? fromWire(Object? name) {
    for (final field in values) {
      if (field.wireName == name) {
        return field;
      }
    }
    return null;
  }
}

/// Why a write failed: the request failed ([SaveApiFailure]), or the backend
/// refused one field's value with a `400` ([SaveRejected]), which the editor
/// shows under that field, on its step (T-0048-AC2).
sealed class SaveFailure {
  const SaveFailure();

  /// The failure as the kit's type (`WizardController` completes with an
  /// `ApiFailure`).
  ApiFailure get asApiFailure;
}

/// The write did not go through (offline, a `5xx`, a `404`, a `400` that
/// names no field of the editor, ...).
final class SaveApiFailure extends SaveFailure {
  const SaveApiFailure(this.failure);

  final ApiFailure failure;

  @override
  ApiFailure get asApiFailure => failure;

  @override
  String toString() => 'SaveApiFailure($failure)';
}

/// The backend refused [field]'s value; [code] is its `error.code`
/// (`invalid_name`, `too_many_comics`, ...).
final class SaveRejected extends SaveFailure {
  const SaveRejected({required this.field, required this.code});

  final ListField field;
  final String code;

  /// A `400` naming the field and the code.
  @override
  ApiFailure get asApiFailure =>
      ApiFailure.clientError(400, '${field.wireName}: $code');

  @override
  String toString() => 'SaveRejected(${field.name}, $code)';
}
