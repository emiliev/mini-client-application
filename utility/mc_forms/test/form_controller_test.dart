import 'dart:async';

import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:test/test.dart';

List<FieldSpec> _fields() => [
  FieldDef<String>(
    'email',
    initial: '',
    validators: [Validators.required(), Validators.minLength(3)],
  ),
  FieldDef<String>(
    'password',
    initial: '',
    validators: [Validators.required()],
  ),
  FieldDef<String>(
    'confirm',
    initial: '',
    crossValidators: [Validators.matches('password')],
  ),
];

({FormController controller, List<McFormState> states}) _make({
  List<FieldSpec>? fields,
}) {
  final states = <McFormState>[];
  final controller = FormController(
    fields: fields ?? _fields(),
    onState: states.add,
  );
  return (controller: controller, states: states);
}

void _fill(FormController c) {
  c
    ..setValue('email', 'a@b.c')
    ..setValue('password', 'secret')
    ..setValue('confirm', 'secret');
}

void main() {
  group('T-0045-AC2 field state', () {
    test(
      'T-0045-AC2 starts pristine: not dirty, not touched, errors known',
      () {
        final m = _make();
        final email = m.controller.state.field('email');
        expect(email.dirty, isFalse);
        expect(email.touched, isFalse);
        expect(email.error, const FieldError(ValidationCode.required));
        expect(email.visibleError, isNull);
        expect(m.controller.state.isValid, isFalse);
        expect(m.controller.state.isDirty, isFalse);
        expect(m.states, isEmpty);
      },
    );

    test('T-0045-AC2 setValue makes the field dirty and re-checks it', () {
      final m = _make()..controller.setValue('email', 'ab');
      final email = m.controller.state.field('email');
      expect(email.value, 'ab');
      expect(email.dirty, isTrue);
      expect(email.error, const FieldError(ValidationCode.tooShort, min: 3));
      expect(email.visibleError, isNull, reason: 'not touched yet');
      expect(m.controller.state.isDirty, isTrue);
    });

    test('T-0045-AC2 setting the initial value back is not dirty', () {
      final m = _make()
        ..controller.setValue('email', 'abc')
        ..controller.setValue('email', '');
      expect(m.controller.state.field('email').dirty, isFalse);
    });

    test('T-0045-AC2 touch makes the error visible', () {
      final m = _make()..controller.touch('email');
      expect(
        m.controller.state.field('email').visibleError,
        const FieldError(ValidationCode.required),
      );
      expect(m.controller.state.visibleErrors.keys, ['email']);
      expect(m.controller.state.errors.keys, ['email', 'password']);
    });

    test('T-0045-AC2 touching an already touched field emits nothing', () {
      final m = _make()
        ..controller.touch('email')
        ..controller.touch('email');
      expect(m.states, hasLength(1));
    });

    test('T-0045-AC2 a cross-field error follows the other field', () {
      final m = _make()
        ..controller.setValue('confirm', 'x')
        ..controller.setValue('password', 'x');
      expect(m.controller.state.field('confirm').error, isNull);
      m.controller.setValue('password', 'y');
      expect(
        m.controller.state.field('confirm').error,
        const FieldError(ValidationCode.mismatch),
      );
    });

    test('T-0045-AC2 an unknown field is an ArgumentError', () {
      final m = _make();
      expect(() => m.controller.setValue('nope', 1), throwsArgumentError);
      expect(() => m.controller.touch('nope'), throwsArgumentError);
      expect(() => m.controller.state.field('nope'), throwsArgumentError);
    });

    test('T-0045-AC2 a duplicate field name is an ArgumentError', () {
      expect(
        () => FormController(
          fields: [const FieldDef<String>('a'), const FieldDef<String>('a')],
          onState: (_) {},
        ),
        throwsArgumentError,
      );
    });

    test('T-0045-AC2 FieldState has value equality', () {
      const a = FieldState<int>(value: 1, initial: 0);
      expect(a, const FieldState<int>(value: 1, initial: 0));
      expect(a.hashCode, const FieldState<int>(value: 1, initial: 0).hashCode);
      expect(a, isNot(const FieldState<int>(value: 2, initial: 0)));
      expect(a, isNot(const FieldState<int>(value: 1, initial: 5)));
      expect(a, isNot(a.touch()));
      expect(a, isNot(a.withError(const FieldError(ValidationCode.invalid))));
      expect(a.toString(), contains('value: 1'));
    });

    test('T-0045-AC2 reset restores initial values and clears touched', () {
      final m = _make();
      _fill(m.controller);
      m.controller
        ..touchAll()
        ..reset();
      final s = m.controller.state;
      expect(s.field('email').value, '');
      expect(s.field('email').touched, isFalse);
      expect(s.submitStatus, SubmitStatus.idle);
    });
  });

  group('T-0045-AC2 submit', () {
    test(
      'T-0045-AC2 an invalid form is not submitted and shows errors',
      () async {
        final m = _make();
        var calls = 0;
        final result = await m.controller.submit<int>((_) async {
          calls++;
          return success(1);
        });
        expect(result, isNull);
        expect(calls, 0);
        expect(m.controller.state.visibleErrors.keys, ['email', 'password']);
        expect(m.controller.state.submitStatus, SubmitStatus.idle);
      },
    );

    test(
      'T-0045-AC2 a valid form runs the action once with the values',
      () async {
        final m = _make();
        _fill(m.controller);
        FormValues? seen;
        final result = await m.controller.submit<int>((values) async {
          seen = values;
          return success(42);
        });
        expect(result!.getOrNull(), 42);
        expect(seen!.get<String>('email'), 'a@b.c');
        expect(m.controller.state.submitStatus, SubmitStatus.succeeded);
        expect(m.controller.state.submitResult, 42);
        expect(
          m.states.map((s) => s.submitStatus),
          containsAllInOrder([SubmitStatus.submitting, SubmitStatus.succeeded]),
        );
      },
    );

    test('T-0045-AC2 a double submit runs one action', () async {
      final m = _make();
      _fill(m.controller);
      final gate = Completer<Result<int, ApiFailure>>();
      var calls = 0;
      Future<Result<int, ApiFailure>> action(FormValues _) {
        calls++;
        return gate.future;
      }

      final first = m.controller.submit<int>(action);
      final second = await m.controller.submit<int>(action);
      expect(second, isNull);
      expect(m.controller.state.isSubmitting, isTrue);
      gate.complete(success(1));
      expect((await first)!.getOrNull(), 1);
      expect(calls, 1);
    });

    test('T-0045-AC2 edits during a submit are ignored', () async {
      final m = _make();
      _fill(m.controller);
      final gate = Completer<Result<int, ApiFailure>>();
      FormValues? submitted;
      final run = m.controller.submit<int>((values) {
        submitted = values;
        return gate.future;
      });
      final before = m.states.length;
      m.controller
        ..setValue('email', 'changed@b.c')
        ..touch('email')
        ..touchAll();
      expect(m.states, hasLength(before), reason: 'nothing was emitted');
      expect(m.controller.state.field('email').value, 'a@b.c');
      gate.complete(success(1));
      await run;
      expect(m.controller.state.values.toMap(), submitted!.toMap());
      expect(m.controller.state.submitStatus, SubmitStatus.succeeded);
    });

    test('T-0045-AC2 fieldOf returns the field typed', () {
      final m = _make()..controller.setValue('email', 'ab');
      final FieldState<String> typed = m.controller.state.fieldOf<String>(
        'email',
      );
      expect(typed.value, 'ab');
      expect(typed.error, const FieldError(ValidationCode.tooShort, min: 3));
      expect(typed.touched, isFalse);
      expect(
        () => m.controller.state.fieldOf<int>('email'),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => m.controller.state.fieldOf<String>('nope'),
        throwsArgumentError,
      );
    });

    test('T-0045-AC2 reset is ignored while submitting', () async {
      final m = _make();
      _fill(m.controller);
      final gate = Completer<Result<int, ApiFailure>>();
      final run = m.controller.submit<int>((_) => gate.future);
      m.controller.reset();
      expect(m.controller.state.field('email').value, 'a@b.c');
      gate.complete(success(1));
      await run;
    });

    test('T-0045-AC2 a failure keeps the values and allows a retry', () async {
      final m = _make();
      _fill(m.controller);
      final first = await m.controller.submit<int>(
        (_) async => failure(const ApiFailure.offline()),
      );
      expect(first!.fold((_) => null, (f) => f), isA<ApiOffline>());
      expect(m.controller.state.submitStatus, SubmitStatus.failed);
      expect(m.controller.state.submitFailure, isA<ApiOffline>());
      expect(m.controller.state.field('email').value, 'a@b.c');

      final second = await m.controller.submit<int>((_) async => success(2));
      expect(second!.getOrNull(), 2);
      expect(m.controller.state.submitFailure, isNull);
    });

    test('T-0045-AC2 editing a failed form clears the failure', () async {
      final m = _make();
      _fill(m.controller);
      await m.controller.submit<int>(
        (_) async => failure(const ApiFailure.offline()),
      );
      m.controller.setValue('email', 'new@b.c');
      expect(m.controller.state.submitStatus, SubmitStatus.idle);
      expect(m.controller.state.submitFailure, isNull);
    });

    test('T-0045-AC2 a thrown Exception becomes a failure', () async {
      final m = _make();
      _fill(m.controller);
      final result = await m.controller.submit<int>(
        (_) async => throw Exception('boom'),
      );
      expect(result!.fold((_) => null, (f) => f), isA<ApiFailure>());
      expect(m.controller.state.submitStatus, SubmitStatus.failed);
    });

    test(
      'T-0045-AC2 an Error propagates and does not leave it submitting',
      () async {
        final m = _make();
        _fill(m.controller);
        await expectLater(
          m.controller.submit<int>((_) async => throw StateError('bug')),
          throwsStateError,
        );
        expect(m.controller.state.submitStatus, SubmitStatus.idle);
        final again = await m.controller.submit<int>((_) async => success(1));
        expect(again!.getOrNull(), 1);
      },
    );

    test('T-0045-AC2 a disposed controller does not emit or submit', () async {
      final m = _make();
      _fill(m.controller);
      final gate = Completer<Result<int, ApiFailure>>();
      final run = m.controller.submit<int>((_) => gate.future);
      final before = m.states.length;
      m.controller.dispose();
      gate.complete(success(1));
      expect((await run)!.getOrNull(), 1);
      expect(m.states, hasLength(before));
      expect(await m.controller.submit<int>((_) async => success(2)), isNull);
    });
  });
}
