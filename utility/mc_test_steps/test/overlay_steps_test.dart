// T-0058-AC4: each overlay step passes when it should and goes red when it
// should (negative controls), over the real DS overlays.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

Future<void> _red(Future<void> step) async {
  try {
    await step;
  } on TestFailure {
    return;
  }
  fail('the step passed, but it should have failed');
}

const _homeKey = Key('steps.home');

Widget _app() => MaterialApp(
  theme: McTheme.light,
  home: const Scaffold(body: Center(key: _homeKey)),
);

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_homeKey));

Future<void> _openConfirm(WidgetTester tester, List<bool> answers) async {
  unawaited(
    showMcConfirm(
      _ctx(tester),
      title: 'Delete?',
      message: 'Gone for good.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    ).then(answers.add),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T-0058-AC4 I confirm the dialog', (tester) async {
    await tester.pumpWidget(_app());
    final answers = <bool>[];

    // Negative control: nothing is open.
    await _red(iConfirmTheDialog(tester));
    expect(answers, isEmpty);

    await _openConfirm(tester, answers);
    await iConfirmTheDialog(tester);
    expect(answers, [true]);
    expect(find.byType(McDialog), findsNothing);

    // Negative control: the dialog is gone again.
    await _red(iConfirmTheDialog(tester));
  });

  testWidgets('T-0058-AC4 I cancel the dialog', (tester) async {
    await tester.pumpWidget(_app());
    final answers = <bool>[];

    await _red(iCancelTheDialog(tester));

    await _openConfirm(tester, answers);
    await iCancelTheDialog(tester);
    expect(answers, [false]);
    expect(find.byType(McDialog), findsNothing);
    await _red(iCancelTheDialog(tester));
  });

  testWidgets('T-0058-AC4 I choose {option} in the sheet', (tester) async {
    await tester.pumpWidget(_app());

    // Negative control: no sheet is open.
    await _red(iChooseInTheSheet(tester, 'Dark'));

    final answers = <String?>[];
    unawaited(
      showMcChoiceSheet<String>(
        _ctx(tester),
        title: 'Appearance',
        dismissLabel: 'Close',
        options: const [
          McChoiceOption(value: 'light', label: 'Light'),
          McChoiceOption(value: 'dark', label: 'Dark'),
        ],
      ).then(answers.add),
    );
    await tester.pumpAndSettle();

    // Negative controls: an option the sheet does not have, and a prefix of
    // one that it does.
    await _red(iChooseInTheSheet(tester, 'Sepia'));
    await _red(iChooseInTheSheet(tester, 'Dar'));
    expect(answers, isEmpty);

    await iChooseInTheSheet(tester, 'Dark');
    expect(answers, ['dark']);
    expect(find.byType(McSheet), findsNothing);
    await _red(iChooseInTheSheet(tester, 'Dark'));
  });

  testWidgets('T-0058-AC4 I choose {option} in the sheet is exact', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    unawaited(
      showMcChoiceSheet<String>(
        _ctx(tester),
        title: 'Twice',
        dismissLabel: 'Close',
        options: const [
          McChoiceOption(value: 'a', label: 'Same'),
          McChoiceOption(value: 'b', label: 'Same'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Negative control: two options read "Same", so the step cannot tell
    // which one is meant and must not pick one.
    await _red(iChooseInTheSheet(tester, 'Same'));
    expect(find.byType(McSheet), findsOneWidget);
  });

  testWidgets('T-0058-AC4 the toast {text} is shown', (tester) async {
    await tester.pumpWidget(_app());

    // Negative control: no toast.
    await _red(theToastIsShown(tester, 'Comic saved'));

    showMcToast(_ctx(tester), 'Comic saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await theToastIsShown(tester, 'Comic saved');

    // Negative controls: other text, a prefix of the text.
    await _red(theToastIsShown(tester, 'Comic removed'));
    await _red(theToastIsShown(tester, 'Comic'));

    // A replaced toast is no longer shown.
    showMcToast(_ctx(tester), 'Comic removed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await theToastIsShown(tester, 'Comic removed');
    await _red(theToastIsShown(tester, 'Comic saved'));

    // An expired toast is no longer shown.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _red(theToastIsShown(tester, 'Comic removed'));
  });

  testWidgets('T-0058-AC4 I choose {option} in the sheet only taps choice '
      'rows', (tester) async {
    await tester.pumpWidget(_app());

    // The sheet's title reads like an option: the step picks the row, not the
    // heading, and does not see two matches.
    final answers = <String?>[];
    unawaited(
      showMcChoiceSheet<String>(
        _ctx(tester),
        title: 'Dark',
        dismissLabel: 'Close',
        options: const [
          McChoiceOption(value: 'light', label: 'Light'),
          McChoiceOption(value: 'dark', label: 'Dark'),
        ],
      ).then(answers.add),
    );
    await tester.pumpAndSettle();
    await iChooseInTheSheet(tester, 'Dark');
    expect(answers, ['dark']);

    // Negative control: a sheet that is not a choice sheet, with the text.
    unawaited(
      showMcSheet<void>(
        _ctx(tester),
        builder: (_) => const McSheet(
          title: 'Dark',
          dismissLabel: 'Close',
          child: Text('Light'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _red(iChooseInTheSheet(tester, 'Dark'));
    await _red(iChooseInTheSheet(tester, 'Light'));
    expect(find.byType(McSheet), findsOneWidget);
  });
}
