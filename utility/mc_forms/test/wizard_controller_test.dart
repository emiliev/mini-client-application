import 'dart:async';

import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:test/test.dart';

const _nameRule = ValidationCode.required;

List<WizardStep> _steps() => [
  WizardStep(
    'details',
    fields: [
      FieldDef<String>(
        'title',
        initial: '',
        validators: [Validators.required(), Validators.maxLength(10)],
      ),
      const FieldDef<String>('note', initial: ''),
    ],
  ),
  WizardStep(
    'books',
    fields: [
      FieldDef<List<String>>(
        'books',
        initial: const [],
        validators: [Validators.required()],
      ),
    ],
  ),
  WizardStep(
    'review',
    fields: [
      FieldDef<bool>(
        'agree',
        initial: false,
        validators: [
          (v) => v == true ? null : const FieldError(ValidationCode.invalid),
        ],
      ),
    ],
  ),
];

class _Harness {
  _Harness({SubmitAction<String>? onComplete}) {
    calls = 0;
    controller = WizardController<String>(
      steps: _steps(),
      onState: states.add,
      onComplete:
          onComplete ??
          (values) async {
            calls++;
            return success('saved ${values.get<String>('title')}');
          },
    );
  }

  final states = <WizardState<String>>[];
  late final WizardController<String> controller;
  late int calls;

  WizardState<String> get s => controller.state;

  void fillStep0() => controller.setValue('title', 'My list');
  void fillStep1() => controller.setValue('books', ['a']);
  void fillAll() {
    fillStep0();
    fillStep1();
    controller.setValue('agree', true);
  }
}

void main() {
  group('T-0045-AC2 wizard errors per step', () {
    test('T-0045-AC2 errors are reported per step', () {
      final h = _Harness();
      expect(h.s.stepErrors(0).keys, ['title']);
      expect(h.s.stepErrors(1).keys, ['books']);
      expect(h.s.stepErrors(2).keys, ['agree']);
      expect(h.s.stepErrors(0)['title']!.code, _nameRule);
      expect(h.s.isStepValid(0), isFalse);
      h.fillStep0();
      expect(h.s.isStepValid(0), isTrue);
      expect(h.s.isStepValid(1), isFalse);
      expect(h.s.currentErrors, isEmpty);
      expect(h.s.stepCount, 3);
      expect(h.s.stepId, 'details');
    });

    test('T-0045-AC2 an invalid step blocks next and shows its errors', () {
      final h = _Harness();
      expect(h.s.canGoNext, isFalse);
      expect(h.s.form.visibleErrors, isEmpty);
      expect(h.controller.next(), isFalse);
      expect(h.s.stepIndex, 0);
      expect(h.s.form.visibleErrors.keys, ['title']);
      expect(
        h.s.form.field('books').visibleError,
        isNull,
        reason: 'other steps stay untouched',
      );
    });

    test('T-0045-AC2 a valid step advances', () {
      final h = _Harness()..fillStep0();
      expect(h.s.canGoNext, isTrue);
      expect(h.controller.next(), isTrue);
      expect(h.s.stepIndex, 1);
      expect(h.s.stepId, 'books');
      expect(h.s.isFirst, isFalse);
    });

    test('T-0045-AC2 back restores the previous step values', () {
      final h = _Harness()..fillStep0();
      h.controller
        ..setValue('note', 'hello')
        ..next()
        ..setValue('books', ['x']);
      expect(h.controller.back(), isTrue);
      expect(h.s.stepIndex, 0);
      expect(h.s.form.field('title').value, 'My list');
      expect(h.s.form.field('note').value, 'hello');
      h.controller.next();
      expect(h.s.form.field('books').value, ['x']);
    });

    test('T-0045-AC2 back keeps the touched state of the step', () {
      final h = _Harness()..controller.next();
      h.fillStep0();
      h.controller.next();
      h.controller.next();
      expect(h.s.stepIndex, 1);
      expect(h.s.form.field('books').touched, isTrue);
      h.controller.back();
      h.controller.back();
      expect(h.s.stepIndex, 0);
      expect(h.s.form.field('title').touched, isTrue);
    });

    test('T-0045-AC2 back on the first step does nothing', () {
      final h = _Harness();
      expect(h.controller.back(), isFalse);
      expect(h.s.stepIndex, 0);
      expect(h.s.canGoBack, isFalse);
    });

    test('T-0045-AC2 next on the last step does nothing', () {
      final h = _Harness()..fillAll();
      h.controller
        ..next()
        ..next();
      expect(h.s.isLast, isTrue);
      expect(h.s.canGoNext, isFalse);
      expect(h.controller.next(), isFalse);
      expect(h.s.stepIndex, 2);
    });

    test('T-0045-AC2 an empty wizard is an ArgumentError', () {
      expect(
        () => WizardController<String>(
          steps: const [],
          onState: (_) {},
          onComplete: (_) async => success(''),
        ),
        throwsArgumentError,
      );
    });

    test('T-0045-AC2 touch is forwarded to the form', () {
      final h = _Harness()..controller.touch('title');
      expect(h.s.form.field('title').visibleError, isNotNull);
    });
  });

  group('T-0045-AC2 wizard completion', () {
    Future<_Harness> readyOnLastStep() async {
      final h = _Harness()..fillAll();
      h.controller
        ..next()
        ..next();
      return h;
    }

    test('T-0045-AC2 completing returns the result once', () async {
      final h = await readyOnLastStep();
      expect(h.s.canComplete, isTrue);
      final result = await h.controller.complete();
      expect(result!.getOrNull(), 'saved My list');
      expect(h.s.isCompleted, isTrue);
      expect(h.s.result, 'saved My list');
      expect(h.s.failure, isNull);
      expect(h.calls, 1);
      expect(await h.controller.complete(), isNull);
      expect(h.calls, 1);
      expect(h.s.canComplete, isFalse);
      expect(h.s.canGoBack, isFalse);
    });

    test('T-0045-AC2 a double complete runs one completion', () async {
      final gate = Completer<Result<String, ApiFailure>>();
      var calls = 0;
      final h = _Harness(
        onComplete: (_) {
          calls++;
          return gate.future;
        },
      )..fillAll();
      h.controller
        ..next()
        ..next();
      final first = h.controller.complete();
      expect(h.s.isCompleting, isTrue);
      expect(h.s.canComplete, isFalse);
      expect(await h.controller.complete(), isNull);
      expect(h.controller.back(), isFalse);
      expect(h.controller.next(), isFalse);
      gate.complete(success('ok'));
      expect((await first)!.getOrNull(), 'ok');
      expect(calls, 1);
      expect(h.s.result, 'ok');
    });

    test('T-0045-AC2 next and back are blocked while completing', () async {
      final gate = Completer<Result<String, ApiFailure>>();
      final h = _Harness(onComplete: (_) => gate.future)..fillAll();
      final run = h.controller.complete();
      expect(h.s.isCompleting, isTrue);
      expect(h.s.stepIndex, 0);
      expect(h.controller.next(), isFalse);
      expect(h.s.stepIndex, 0);
      gate.complete(success('ok'));
      await run;
    });

    test('T-0045-AC2 the last step cannot complete while it is invalid', () {
      final h = _Harness()..fillStep0();
      h.fillStep1();
      h.controller
        ..next()
        ..next();
      expect(h.s.isLast, isTrue);
      expect(h.s.canComplete, isFalse);
      h.controller.setValue('agree', true);
      expect(h.s.canComplete, isTrue);
    });

    test('T-0045-AC2 complete touches only the first invalid step', () async {
      final h = _Harness();
      h.controller.setValue('agree', true);
      expect(await h.controller.complete(), isNull);
      expect(h.s.stepIndex, 0);
      expect(h.s.form.field('title').touched, isTrue);
      expect(h.s.form.field('books').touched, isFalse);
      expect(h.s.form.field('agree').touched, isFalse);
    });

    test('T-0045-AC2 next is blocked once the wizard completed', () async {
      final h = _Harness()..fillAll();
      h.controller
        ..next()
        ..next();
      await h.controller.complete();
      expect(h.s.isCompleted, isTrue);
      h.controller.setValue('agree', true);
      expect(h.s.canGoNext, isFalse);
      // Rewind is not possible either, so force the state: a wizard of two
      // steps completed from the first step.
      final c = WizardController<int>(
        steps: [
          const WizardStep('a', fields: [FieldDef<String>('a', initial: 'x')]),
          const WizardStep('b', fields: [FieldDef<String>('b', initial: 'y')]),
        ],
        onState: (_) {},
        onComplete: (_) async => success(1),
      );
      await c.complete();
      expect(c.state.stepIndex, 0);
      expect(c.state.isCompleted, isTrue);
      expect(c.state.canGoNext, isFalse);
      expect(c.next(), isFalse);
      expect(c.state.stepIndex, 0);
    });

    test('T-0045-AC2 touchCurrentStep touches only the current step', () {
      final h = _Harness()..controller.touchCurrentStep();
      expect(h.s.form.field('title').touched, isTrue);
      expect(h.s.form.field('books').touched, isFalse);
    });

    test('T-0045-AC2 complete with an invalid step jumps to it', () async {
      final h = _Harness()..fillStep0();
      h.controller
        ..next()
        ..setValue('agree', true);
      expect(h.s.stepIndex, 1);
      expect(await h.controller.complete(), isNull);
      expect(h.calls, 0);
      expect(h.s.stepIndex, 1, reason: 'the first invalid step is books');
      expect(h.s.form.field('books').visibleError, isNotNull);
    });

    test('T-0045-AC2 complete jumps back to an earlier invalid step', () async {
      final h = await readyOnLastStep();
      h.controller.setValue('title', '');
      expect(await h.controller.complete(), isNull);
      expect(h.s.stepIndex, 0);
      expect(h.s.form.field('title').visibleError, isNotNull);
    });

    test('T-0045-AC2 a failed completion stays and can be retried', () async {
      var attempt = 0;
      final h = _Harness(
        onComplete: (_) async {
          attempt++;
          return attempt == 1
              ? failure(const ApiFailure.offline())
              : success('second');
        },
      )..fillAll();
      h.controller
        ..next()
        ..next();
      final first = await h.controller.complete();
      expect(first!.fold((_) => null, (f) => f), isA<ApiOffline>());
      expect(h.s.failure, isA<ApiOffline>());
      expect(h.s.isCompleted, isFalse);
      expect(h.s.stepIndex, 2);
      expect(h.s.canComplete, isTrue);
      final second = await h.controller.complete();
      expect(second!.getOrNull(), 'second');
      expect(h.s.result, 'second');
    });

    test('T-0045-AC2 a completion cross-field rule spans steps', () async {
      final steps = [
        WizardStep('one', fields: [const FieldDef<String>('a', initial: 'x')]),
        WizardStep(
          'two',
          fields: [
            FieldDef<String>(
              'b',
              initial: 'y',
              crossValidators: [Validators.matches('a')],
            ),
          ],
        ),
      ];
      final states = <WizardState<int>>[];
      final c = WizardController<int>(
        steps: steps,
        onState: states.add,
        onComplete: (_) async => success(1),
      );
      expect(c.state.isStepValid(1), isFalse);
      c.setValue('b', 'x');
      expect(c.state.isStepValid(1), isTrue);
      c.setValue('a', 'z');
      expect(c.state.isStepValid(1), isFalse);
    });

    test('T-0045-AC2 a disposed wizard stops emitting and moving', () async {
      final h = _Harness()..fillStep0();
      final before = h.states.length;
      h.controller.dispose();
      expect(h.controller.next(), isFalse);
      expect(h.controller.back(), isFalse);
      expect(await h.controller.complete(), isNull);
      h.controller.setValue('note', 'x');
      expect(h.states, hasLength(before));
    });
  });

  group('T-0048-AC2 a server-side error goes to its step', () {
    const taken = FieldError(ValidationCode.invalid);

    test("T-0048-AC2 reject goes back to the field's step and shows the "
        'error there; a new value clears it', () async {
      final h = _Harness(
        onComplete: (_) async =>
            failure(const ApiFailure.clientError(400, 'taken')),
      );
      h.fillAll();
      h.controller
        ..next()
        ..next();
      expect(h.s.stepIndex, 2);
      await h.controller.complete();

      h.controller.reject('title', taken);
      expect(h.s.stepIndex, 0);
      expect(h.s.currentErrors, {'title': taken});
      expect(h.s.form.field('title').visibleError, taken);
      expect(h.s.canGoNext, isFalse);
      expect(h.s.failure, isNull);

      h.controller.setValue('title', 'Other');
      expect(h.s.currentErrors, isEmpty);
      expect(h.s.canGoNext, isTrue);
    });

    test(
      'T-0048-AC2 reject goes forward too, and stays on the step it is on',
      () {
        final h = _Harness()..fillAll();
        h.controller.reject('books', taken);
        expect(h.s.stepIndex, 1);
        final before = h.states.length;
        h.controller.reject('books', taken);
        expect(h.s.stepIndex, 1);
        expect(h.states.length, before + 1, reason: 'no step change emitted');
      },
    );

    test('T-0048-AC2 reject is ignored while completing, once completed and '
        'after dispose', () async {
      final gate = Completer<Result<String, ApiFailure>>();
      final h = _Harness(onComplete: (_) => gate.future)..fillAll();
      final running = h.controller.complete();
      h.controller.reject('title', taken);
      expect(h.s.form.field('title').error, isNull);
      gate.complete(success('ok'));
      await running;
      h.controller.reject('title', taken);
      expect(h.s.form.field('title').error, isNull);
      expect(h.s.stepIndex, 0);

      final d = _Harness()..fillAll();
      d.controller
        ..dispose()
        ..reject('books', taken);
      expect(d.s.stepIndex, 0);
    });
  });
}
