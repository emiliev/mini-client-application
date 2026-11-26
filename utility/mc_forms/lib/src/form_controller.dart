import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/src/field_spec.dart';
import 'package:mc_forms/src/field_state.dart';
import 'package:mc_forms/src/form_state.dart';
import 'package:mc_forms/src/form_values.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Does the work of a submit. A thrown `Exception` is mapped with
/// `ApiFailure.from`.
typedef SubmitAction<R> = Future<Result<R, ApiFailure>> Function(
  FormValues values,
);

/// Drives an [McFormState]. A bloc owns one and forwards `onState` to `emit`;
/// it is a plain helper, not a mixin (cutoff-critical kit).
///
/// Every change re-checks every field, so a cross-field rule (confirm equals)
/// stays current when the other field changes. Errors are always computed;
/// the UI shows `visibleError`, which waits for the field to be touched.
final class FormController {
  FormController({required List<FieldSpec> fields, required this.onState})
    : _specs = _index(fields) {
    final initial = FormValues({for (final f in fields) f.name: f.initial});
    _state = McFormState(
      fields: {
        for (final f in fields)
          f.name: FieldState<Object?>(
            value: f.initial,
            initial: f.initial,
            error: f.check(f.initial, initial),
          ),
      },
    );
  }

  final Map<String, FieldSpec> _specs;

  /// Called with every new state.
  final void Function(McFormState state) onState;

  late McFormState _state;
  bool _disposed = false;

  McFormState get state => _state;

  /// Sets a value, re-checks the form and clears a failed submit. Ignored
  /// while a submit runs, so the form ends as it was submitted. Throws an
  /// [ArgumentError] for an unknown field.
  void setValue(String name, Object? value) {
    _spec(name);
    if (_state.isSubmitting) {
      return;
    }
    _emit(
      _revalidate(
        {
          for (final e in _state.fields.entries)
            e.key: e.key == name
                ? FieldState<Object?>(
                    value: value,
                    initial: e.value.initial,
                    touched: e.value.touched,
                  )
                : e.value,
        },
        failed: _state.submitStatus == SubmitStatus.failed
            ? SubmitStatus.idle
            : null,
      ),
    );
  }

  /// Marks a field as touched (it lost focus), so its error shows.
  void touch(String name) => touchAll(names: [name]);

  /// Marks [names] (default: every field) as touched.
  void touchAll({Iterable<String>? names}) {
    final targets = (names ?? _specs.keys).toSet();
    targets.forEach(_spec);
    if (_state.isSubmitting) {
      return;
    }
    final next = {
      for (final e in _state.fields.entries)
        e.key: targets.contains(e.key) ? e.value.touch() : e.value,
    };
    if (!_sameFields(next)) {
      _emit(_state.withFields(next));
    }
  }

  /// Back to the initial values: untouched, no submit outcome. Does nothing
  /// while a submit runs.
  void reset() {
    if (_state.isSubmitting) {
      return;
    }
    final values = FormValues({
      for (final e in _specs.entries) e.key: e.value.initial,
    });
    _emit(
      McFormState(
        fields: {
          for (final e in _specs.entries)
            e.key: FieldState<Object?>(
              value: e.value.initial,
              initial: e.value.initial,
              error: e.value.check(e.value.initial, values),
            ),
        },
      ),
    );
  }

  /// Touches every field, and when the form is valid runs [action] once.
  ///
  /// Returns null without running anything when the form is invalid, a
  /// submit is already running (a double tap), or the controller is
  /// disposed. A failure keeps the values and sets `submitFailure`; the form
  /// can then be edited and submitted again. An `Error` is a bug: it
  /// propagates after the status is settled.
  Future<Result<R, ApiFailure>?> submit<R>(SubmitAction<R> action) async {
    if (_disposed || _state.isSubmitting) {
      return null;
    }
    touchAll();
    if (!_state.isValid) {
      return null;
    }
    _emit(_withStatus(SubmitStatus.submitting));

    Result<R, ApiFailure> result;
    try {
      result = await action(_state.values);
    } on Exception catch (error) {
      result = failure(ApiFailure.from(error));
    } on Object {
      _emit(_withStatus(SubmitStatus.idle));
      rethrow;
    }
    _emit(
      result.fold(
        (value) => McFormState(
          fields: _state.fields,
          submitStatus: SubmitStatus.succeeded,
          submitResult: value,
        ),
        (error) => McFormState(
          fields: _state.fields,
          submitStatus: SubmitStatus.failed,
          submitFailure: error,
        ),
      ),
    );
    return result;
  }

  /// Stops emitting. A submit already running still finishes quietly.
  void dispose() => _disposed = true;

  McFormState _withStatus(SubmitStatus status) =>
      McFormState(fields: _state.fields, submitStatus: status);

  McFormState _revalidate(
    Map<String, FieldState<Object?>> fields, {
    SubmitStatus? failed,
  }) {
    final values = FormValues({
      for (final e in fields.entries) e.key: e.value.value,
    });
    final checked = {
      for (final e in fields.entries)
        e.key: e.value.withError(_specs[e.key]!.check(e.value.value, values)),
    };
    return failed == null
        ? _state.withFields(checked)
        : McFormState(fields: checked, submitStatus: failed);
  }

  bool _sameFields(Map<String, FieldState<Object?>> next) {
    for (final e in next.entries) {
      if (_state.fields[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }

  FieldSpec _spec(String name) =>
      _specs[name] ??
      (throw ArgumentError.value(name, 'name', 'unknown field'));

  void _emit(McFormState next) {
    _state = next;
    if (!_disposed) {
      onState(next);
    }
  }

  static Map<String, FieldSpec> _index(List<FieldSpec> fields) {
    final map = <String, FieldSpec>{};
    for (final f in fields) {
      if (map.containsKey(f.name)) {
        throw ArgumentError.value(f.name, 'fields', 'duplicate field name');
      }
      map[f.name] = f;
    }
    return map;
  }
}
