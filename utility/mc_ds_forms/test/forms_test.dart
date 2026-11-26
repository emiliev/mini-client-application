import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

String _stepLabel(int step, int total) => 'Step $step of $total';

Widget _app(
  Widget child, {
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
}) => MaterialApp(
  theme: McTheme.of(variant).copyWith(platform: TargetPlatform.iOS),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

McWizardStepper _stepper({
  int current = 1,
  int count = 3,
  VoidCallback? onBack,
  VoidCallback? onNext,
  String back = 'Back',
  String next = 'Next',
}) => McWizardStepper(
  currentStep: current,
  stepCount: count,
  stepLabel: _stepLabel,
  backLabel: back,
  nextLabel: next,
  onBack: onBack,
  onNext: onNext,
);

McButton _button(WidgetTester tester, Key key) => tester.widget<McButton>(
  find.descendant(of: find.byKey(key), matching: find.byType(McButton)),
);

WizardState<String> _wizard({
  required int step,
  bool valid = true,
  bool agree = true,
}) {
  final c = WizardController<String>(
    steps: [
      WizardStep(
        'one',
        fields: [
          FieldDef<String>(
            'title',
            initial: valid ? 'x' : '',
            validators: [Validators.required()],
          ),
        ],
      ),
      WizardStep(
        'two',
        fields: [
          FieldDef<bool>(
            'agree',
            initial: agree,
            validators: [
              (v) =>
                  v == true ? null : const FieldError(ValidationCode.invalid),
            ],
          ),
        ],
      ),
    ],
    onState: (_) {},
    onComplete: (_) async => success('ok'),
  );
  if (step == 1) {
    c.next();
  }
  return c.state;
}

String _message(FieldError e) => switch (e.code) {
  ValidationCode.required => 'Required',
  ValidationCode.tooShort => 'At least ${e.min} characters',
  _ => 'Invalid',
};

/// A two-step wizard: step one has a name (required, at least 3 characters),
/// step two has a note. State changes rebuild through setState, as a bloc
/// would.
class _Wizard extends StatefulWidget {
  const _Wizard();

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  late final WizardController<String> controller = WizardController<String>(
    steps: [
      WizardStep(
        'name',
        fields: [
          FieldDef<String>(
            'name',
            initial: '',
            validators: [Validators.required(), Validators.minLength(3)],
          ),
        ],
      ),
      const WizardStep('note', fields: [FieldDef<String>('note', initial: '')]),
    ],
    onState: (_) => setState(() {}),
    onComplete: (_) async => success('done'),
  );

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final name = s.form.field('name');
    final note = s.form.field('note');
    return Scaffold(
      body: McFieldGroup(
        title: s.stepId == 'name' ? 'Your name' : 'Your note',
        description: 'Step description',
        children: [
          if (s.stepId == 'name')
            McFormTextField(
              field: FieldState<String>(
                value: name.value as String?,
                initial: name.initial as String?,
                error: name.error,
                touched: name.touched,
              ),
              label: 'Name',
              onChanged: (v) => controller.setValue('name', v),
              onTouched: () => controller.touch('name'),
              errorMessage: _message,
            )
          else
            McFormTextField(
              field: FieldState<String>(
                value: note.value as String?,
                initial: note.initial as String?,
                error: note.error,
                touched: note.touched,
              ),
              label: 'Note',
              onChanged: (v) => controller.setValue('note', v),
              onTouched: () => controller.touch('note'),
              errorMessage: _message,
            ),
        ],
      ),
      bottomNavigationBar: McWizardStepper.fromState(
        s,
        stepLabel: _stepLabel,
        backLabel: 'Back',
        nextLabel: 'Next',
        finishLabel: 'Finish',
        onBack: controller.back,
        onNext: () {
          if (s.isLast) {
            controller.complete();
          } else {
            controller.next();
          }
        },
      ),
    );
  }
}

Widget _wizardApp() => MaterialApp(
  theme: McTheme.light.copyWith(platform: TargetPlatform.iOS),
  home: const _Wizard(),
);

SemanticsData _data(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

void main() {
  setUpAll(mcLoadFonts);

  group('T-0045-AC3 wizard stepper', () {
    testWidgets('T-0045-AC3 Next is disabled when its callback is null', (
      tester,
    ) async {
      var backs = 0;
      await tester.pumpWidget(_app(_stepper(onBack: () => backs++)));
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.tap(find.text('Back'));
      expect(backs, 1);
    });

    testWidgets('T-0045-AC3 Next and Back call back when enabled', (
      tester,
    ) async {
      var nexts = 0;
      var backs = 0;
      await tester.pumpWidget(
        _app(_stepper(onBack: () => backs++, onNext: () => nexts++)),
      );
      await tester.tap(find.text('Next'));
      await tester.tap(find.text('Back'));
      expect(nexts, 1);
      expect(backs, 1);
    });

    testWidgets('T-0045-AC3 Back is disabled when its callback is null', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_stepper(current: 0, onNext: () {})));
      expect(_button(tester, McWizardStepper.backKey).onPressed, isNull);
    });

    testWidgets('T-0045-AC3 the indicator announces "Step n of m"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_stepper(onNext: () {})));
      final data = _data(tester, find.bySemanticsLabel('Step 2 of 3'));
      expect(data.label, 'Step 2 of 3');
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tester.pumpWidget(_app(_stepper(current: 2, onNext: () {})));
      expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsNothing);
      handle.dispose();
    });

    testWidgets('T-0045-AC3 the indicator paints one segment per step', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_stepper(count: 5, onNext: () {})));
      final segments = tester.widgetList<DecoratedBox>(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius != null &&
              w.child is SizedBox &&
              (w.child! as SizedBox).height == 4,
        ),
      );
      expect(segments, hasLength(5));
      final colors = [
        for (final s in segments) (s.decoration as BoxDecoration).color,
      ];
      expect(colors.toSet(), hasLength(2), reason: 'done and todo differ');
      expect(colors.where((c) => c == colors.first), hasLength(2));
    });

    testWidgets('T-0045-AC3 every tap target is at least 44 pt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_stepper(onBack: () {}, onNext: () {})),
      );
      for (final key in [McWizardStepper.backKey, McWizardStepper.nextKey]) {
        final size = tester.getSize(
          find.descendant(of: find.byKey(key), matching: find.byType(McButton)),
        );
        expect(size.height, greaterThanOrEqualTo(44));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'T-0045-AC3 long German labels at ${scale}x do not overflow',
        (
          tester,
        ) async {
          mcSetSurface(tester, 375, 800);
          await tester.pumpWidget(
            _app(
              scale: scale,
              _stepper(
                onBack: () {},
                onNext: () {},
                back: 'Zurueck zur vorherigen Seite',
                next: 'Weiter zum naechsten Schritt',
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('T-0045-AC3 fromState: an invalid step disables Next', (
      tester,
    ) async {
      var nexts = 0;
      await tester.pumpWidget(
        _app(
          McWizardStepper.fromState(
            _wizard(step: 0, valid: false),
            stepLabel: _stepLabel,
            backLabel: 'Back',
            nextLabel: 'Next',
            finishLabel: 'Finish',
            onBack: () {},
            onNext: () => nexts++,
          ),
        ),
      );
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
      expect(_button(tester, McWizardStepper.backKey).onPressed, isNull);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(nexts, 0);
    });

    testWidgets('T-0045-AC3 fromState: a valid step enables Next', (
      tester,
    ) async {
      var nexts = 0;
      await tester.pumpWidget(
        _app(
          McWizardStepper.fromState(
            _wizard(step: 0),
            stepLabel: _stepLabel,
            backLabel: 'Back',
            nextLabel: 'Next',
            finishLabel: 'Finish',
            onBack: () {},
            onNext: () => nexts++,
          ),
        ),
      );
      await tester.tap(find.text('Next'));
      expect(nexts, 1);
    });

    testWidgets('T-0045-AC3 fromState: the last step shows Finish', (
      tester,
    ) async {
      Widget build(WizardState<String> s, VoidCallback onNext) => _app(
        McWizardStepper.fromState(
          s,
          stepLabel: _stepLabel,
          backLabel: 'Back',
          nextLabel: 'Next',
          finishLabel: 'Finish',
          onBack: () {},
          onNext: onNext,
        ),
      );
      var finishes = 0;
      await tester.pumpWidget(build(_wizard(step: 1), () => finishes++));
      expect(find.text('Next'), findsNothing);
      expect(_button(tester, McWizardStepper.backKey).onPressed, isNotNull);
      await tester.tap(find.text('Finish'));
      expect(finishes, 1);

      await tester.pumpWidget(
        build(_wizard(step: 1, agree: false), () => finishes++),
      );
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
    });

    testWidgets('T-0045-AC3 fromState: both buttons are off while completing', (
      tester,
    ) async {
      final gate = Completer<Result<String, ApiFailure>>();
      late WizardState<String> state;
      final c = WizardController<String>(
        steps: [
          const WizardStep(
            'one',
            fields: [FieldDef<String>('a', initial: 'x')],
          ),
        ],
        onState: (s) => state = s,
        onComplete: (_) => gate.future,
      );
      final run = c.complete();
      await tester.pumpWidget(
        _app(
          McWizardStepper.fromState(
            state,
            stepLabel: _stepLabel,
            backLabel: 'Back',
            nextLabel: 'Next',
            finishLabel: 'Finish',
            onBack: () {},
            onNext: () {},
          ),
        ),
      );
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
      expect(_button(tester, McWizardStepper.backKey).onPressed, isNull);
      gate.complete(success('ok'));
      await run;
    });
  });

  group('T-0045-AC3 fields bound to the form state', () {
    testWidgets('T-0045-AC3 Next is disabled and no error shows before touch', (
      tester,
    ) async {
      await tester.pumpWidget(_wizardApp());
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
      expect(find.text('Required'), findsNothing);
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('T-0045-AC3 the error shows under the field after it is left', (
      tester,
    ) async {
      await tester.pumpWidget(_wizardApp());
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      expect(
        find.text('At least 3 characters'),
        findsNothing,
        reason: 'not touched yet',
      );
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('At least 3 characters'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('At least 3 characters')).dy,
        greaterThan(tester.getBottomLeft(find.byType(TextField)).dy - 40),
        reason: 'the message sits at the bottom of the field',
      );
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNull);
    });

    testWidgets('T-0045-AC3 the field error is announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wizardApp());
      await tester.tap(find.byType(TextField));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final error = _data(tester, find.bySemanticsLabel('Required'));
      expect(error.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('T-0045-AC3 a valid value clears the error and enables Next', (
      tester,
    ) async {
      await tester.pumpWidget(_wizardApp());
      await tester.enterText(find.byType(TextField), 'ab');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('At least 3 characters'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text('At least 3 characters'), findsNothing);
      expect(_button(tester, McWizardStepper.nextKey).onPressed, isNotNull);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Your note'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'abc',
        reason: 'going back restores the value',
      );
    });

    testWidgets('T-0045-AC3 a value set from outside updates the text', (
      tester,
    ) async {
      await tester.pumpWidget(_wizardApp());
      await tester.enterText(find.byType(TextField), 'abc');
      final state = tester.state<_WizardState>(find.byType(_Wizard));
      state.controller.setValue('name', 'zed');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'zed',
      );
    });

    testWidgets('T-0045-AC3 a field shows its initial value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          home: Scaffold(
            body: McFormTextField(
              field: const FieldState<String>(value: 'Ada', initial: 'Ada'),
              label: 'Name',
              onChanged: (_) {},
              onTouched: () {},
              errorMessage: _message,
            ),
          ),
        ),
      );
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('T-0045-AC3 touch is reported once when focus leaves', (
      tester,
    ) async {
      var touched = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                McFormTextField(
                  field: const FieldState<String>(value: '', initial: ''),
                  label: 'Name',
                  onChanged: (_) {},
                  onTouched: () => touched++,
                  errorMessage: _message,
                ),
                const TextField(),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(touched, 0, reason: 'focused, not left');
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      expect(touched, 1);
    });

    testWidgets('T-0045-AC3 the group title is a semantics header', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wizardApp());
      final data = _data(tester, find.text('Your name'));
      expect(data.flagsCollection.isHeader, isTrue);
      expect(find.text('Step description'), findsOneWidget);
      handle.dispose();
    });
  });

  group('T-0045-AC3 form scaffold', () {
    Widget scaffold({
      VoidCallback? onSubmit,
      bool busy = false,
      String? error,
      Widget? body,
    }) => MaterialApp(
      theme: McTheme.light.copyWith(platform: TargetPlatform.iOS),
      home: McFormScaffold(
        body: body ?? const SizedBox(height: 100, child: Text('fields')),
        submitLabel: 'Save',
        busyLabel: 'Saving',
        onSubmit: onSubmit,
        isSubmitting: busy,
        errorText: error,
      ),
    );

    testWidgets('T-0045-AC3 the submit button calls onSubmit', (tester) async {
      var submits = 0;
      await tester.pumpWidget(scaffold(onSubmit: () => submits++));
      await tester.tap(find.text('Save'));
      expect(submits, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('T-0045-AC3 a null onSubmit disables the button', (
      tester,
    ) async {
      await tester.pumpWidget(scaffold());
      final button = tester.widget<McButton>(find.byType(McButton));
      expect(button.onPressed, isNull);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('T-0045-AC3 busy shows a spinner and blocks taps', (
      tester,
    ) async {
      var submits = 0;
      await tester.pumpWidget(scaffold(onSubmit: () => submits++, busy: true));
      expect(find.text('Saving'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Saving'), warnIfMissed: false);
      expect(submits, 0);
      expect(tester.widget<McButton>(find.byType(McButton)).onPressed, isNull);
    });

    testWidgets('T-0045-AC3 an error shows above the button and is announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(scaffold(onSubmit: () {}, error: 'Offline'));
      expect(find.text('Offline'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Offline')).dy,
        lessThan(tester.getTopLeft(find.byType(McButton)).dy),
      );
      final data = _data(tester, find.text('Offline'));
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, 'Offline');
      handle.dispose();
    });

    testWidgets('T-0045-AC3 a short body leaves the bar at the bottom', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(scaffold(onSubmit: () {}));
      expect(
        tester.getBottomLeft(find.byType(McButton)).dy,
        greaterThan(500),
        reason: 'the bar is pinned to the bottom, not under the body',
      );
    });

    testWidgets('T-0045-AC3 dragging the body dismisses the keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(scaffold(onSubmit: () {}));
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    testWidgets('T-0045-AC3 no error text without an error', (tester) async {
      await tester.pumpWidget(scaffold(onSubmit: () {}));
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('T-0045-AC3 a tall body scrolls and the bar stays', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        scaffold(
          onSubmit: () {},
          body: Column(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 60, child: Text('row $i')),
            ],
          ),
        ),
      );
      expect(tester.getTopLeft(find.text('row 29')).dy, greaterThan(600));
      final before = tester.getTopLeft(find.byType(McButton));
      await tester.drag(find.text('row 1'), const Offset(0, -2000));
      await tester.pump();
      expect(tester.getTopLeft(find.text('row 29')).dy, lessThan(600));
      expect(tester.getTopLeft(find.byType(McButton)), before);
    });

    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('T-0045-AC3 the busy bar at ${scale}x does not overflow', (
        tester,
      ) async {
        mcSetSurface(tester, 375, 800);
        await tester.pumpWidget(
          _app(
            scale: scale,
            const SizedBox(
              height: 700,
              child: McFormScaffold(
                body: Text('fields'),
                submitLabel: 'Speichern',
                busyLabel: 'Wird gespeichert, bitte warten',
                onSubmit: null,
                isSubmitting: true,
                errorText: 'Die Verbindung wurde unterbrochen, bitte erneut',
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
