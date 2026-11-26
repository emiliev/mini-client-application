import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/src/field_error.dart';
import 'package:mc_forms/src/field_spec.dart';
import 'package:mc_forms/src/form_controller.dart';
import 'package:mc_forms/src/form_state.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// One step of a wizard: the fields it asks for.
final class WizardStep {
  const WizardStep(this.id, {required this.fields});

  /// A stable name, for analytics and tests.
  final String id;

  final List<FieldSpec> fields;
}

/// The state of a wizard: one form over every step's fields, and the current
/// step. Immutable.
final class WizardState<R> {
  const WizardState({
    required this.form,
    required this.stepIndex,
    required this.stepFields,
    required this.stepIds,
  });

  final McFormState form;
  final int stepIndex;

  /// The field names of each step, in step order.
  final List<List<String>> stepFields;
  final List<String> stepIds;

  int get stepCount => stepFields.length;
  bool get isFirst => stepIndex == 0;
  bool get isLast => stepIndex == stepCount - 1;
  String get stepId => stepIds[stepIndex];

  /// Every current error of step [index], touched or not.
  Map<String, FieldError> stepErrors(int index) => {
    for (final name in stepFields[index])
      if (form.field(name).error != null) name: form.field(name).error!,
  };

  bool isStepValid(int index) => stepErrors(index).isEmpty;

  Map<String, FieldError> get currentErrors => stepErrors(stepIndex);

  bool get isCurrentStepValid => isStepValid(stepIndex);

  /// The wizard is running its completion.
  bool get isCompleting => form.isSubmitting;

  bool get isCompleted => form.submitStatus == SubmitStatus.succeeded;

  /// Set once the completion succeeded.
  R? get result => isCompleted ? form.submitResult as R? : null;

  /// Set when the completion failed.
  ApiFailure? get failure => form.submitFailure;

  /// Next is available: a step after this one, valid, and not completing.
  bool get canGoNext => !isLast && isCurrentStepValid && !isCompleting;

  /// The last step is valid and nothing runs: a submit is allowed.
  bool get canComplete =>
      isLast && isCurrentStepValid && !isCompleting && !isCompleted;

  bool get canGoBack => !isFirst && !isCompleting && !isCompleted;
}

/// Walks a user through [steps] and completes once.
///
/// All steps share one field map, so values and touched state survive going
/// back and forth, and a cross-field rule can read a field of another step.
/// [next] is blocked while the current step is invalid and then touches the
/// step's fields so their errors show. [complete] checks every step, jumps
/// to the first invalid one, and otherwise runs `onComplete` once; a second
/// call while it runs, or after it succeeded, does nothing.
///
/// A plain helper like `PagingController`, not a mixin: a bloc owns one and
/// forwards `onState` to `emit`.
final class WizardController<R> {
  WizardController({
    required List<WizardStep> steps,
    required this.onState,
    required SubmitAction<R> onComplete,
  }) : _steps = List<WizardStep>.unmodifiable(steps),
       _onComplete = onComplete {
    if (steps.isEmpty) {
      throw ArgumentError.value(steps, 'steps', 'must not be empty');
    }
    _form = FormController(
      fields: [for (final s in steps) ...s.fields],
      onState: _onForm,
    );
    _state = _build(_form.state, 0);
  }

  final List<WizardStep> _steps;
  final SubmitAction<R> _onComplete;

  /// Called with every new state.
  final void Function(WizardState<R> state) onState;

  late final FormController _form;
  late WizardState<R> _state;
  bool _disposed = false;

  WizardState<R> get state => _state;

  void setValue(String name, Object? value) => _form.setValue(name, value);

  void touch(String name) => _form.touch(name);

  /// Advances when the current step is valid. Otherwise touches the step's
  /// fields (their errors show) and stays. Returns whether it advanced; on
  /// the last step it does nothing (use [complete]).
  bool next() {
    if (_disposed || _state.isLast || _state.isCompleting) {
      return false;
    }
    if (!_state.isCurrentStepValid) {
      _form.touchAll(names: _state.stepFields[_state.stepIndex]);
      return false;
    }
    _goTo(_state.stepIndex + 1);
    return true;
  }

  /// Goes to the previous step; its values are as the user left them.
  /// Returns whether it moved.
  bool back() {
    if (_disposed || !_state.canGoBack) {
      return false;
    }
    _goTo(_state.stepIndex - 1);
    return true;
  }

  /// Completes the wizard. Returns null without running anything when a
  /// step is invalid (the wizard then shows the first invalid step with its
  /// errors visible), when a completion is running or done, or when
  /// disposed. Otherwise returns the outcome of `onComplete`.
  Future<Result<R, ApiFailure>?> complete() async {
    if (_disposed || _state.isCompleting || _state.isCompleted) {
      return null;
    }
    _form.touchAll();
    for (var i = 0; i < _state.stepCount; i++) {
      if (!_state.isStepValid(i)) {
        _goTo(i);
        return null;
      }
    }
    return _form.submit<R>(_onComplete);
  }

  void dispose() {
    _disposed = true;
    _form.dispose();
  }

  void _goTo(int index) => _emit(_build(_form.state, index));

  void _onForm(McFormState form) => _emit(_build(form, _state.stepIndex));

  WizardState<R> _build(McFormState form, int index) => WizardState<R>(
    form: form,
    stepIndex: index,
    stepFields: [
      for (final s in _steps) [for (final f in s.fields) f.name],
    ],
    stepIds: [for (final s in _steps) s.id],
  );

  // No disposed check: every caller is guarded, and the form (the only other
  // source) stops emitting on dispose.
  void _emit(WizardState<R> next) {
    _state = next;
    onState(next);
  }
}
