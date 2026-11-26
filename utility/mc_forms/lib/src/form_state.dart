import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/src/field_error.dart';
import 'package:mc_forms/src/field_state.dart';
import 'package:mc_forms/src/form_values.dart';

enum SubmitStatus { idle, submitting, succeeded, failed }

/// The state of a whole form: every field plus the submit status. Named
/// `McFormState` so it never clashes with Flutter's `FormState`. Immutable.
final class McFormState {
  McFormState({
    required Map<String, FieldState<Object?>> fields,
    this.submitStatus = SubmitStatus.idle,
    this.submitFailure,
    this.submitResult,
  }) : fields = Map<String, FieldState<Object?>>.unmodifiable(fields);

  final Map<String, FieldState<Object?>> fields;
  final SubmitStatus submitStatus;

  /// Set when [submitStatus] is [SubmitStatus.failed].
  final ApiFailure? submitFailure;

  /// Set when [submitStatus] is [SubmitStatus.succeeded].
  final Object? submitResult;

  /// Every field passes its rules.
  bool get isValid => fields.values.every((f) => f.isValid);

  bool get isDirty => fields.values.any((f) => f.dirty);

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  /// The field [name]. Throws an [ArgumentError] for an unknown field.
  FieldState<Object?> field(String name) =>
      fields[name] ??
      (throw ArgumentError.value(name, 'name', 'unknown field'));

  /// Every current error, touched or not.
  Map<String, FieldError> get errors => {
    for (final e in fields.entries)
      if (e.value.error != null) e.key: e.value.error!,
  };

  /// Only the errors of touched fields: what the UI shows.
  Map<String, FieldError> get visibleErrors => {
    for (final e in fields.entries)
      if (e.value.visibleError != null) e.key: e.value.visibleError!,
  };

  FormValues get values =>
      FormValues({for (final e in fields.entries) e.key: e.value.value});

  /// The same submit status and outcome over other [fields].
  McFormState withFields(Map<String, FieldState<Object?>> fields) =>
      McFormState(
        fields: fields,
        submitStatus: submitStatus,
        submitFailure: submitFailure,
        submitResult: submitResult,
      );
}
