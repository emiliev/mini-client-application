import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _german =
    'Donaudampfschifffahrtsgesellschaftskapitänsmützenabzeichen-Beschreibung';

const _options = [
  McChipOption<String>(value: 'a', label: 'Helden'),
  McChipOption<String>(value: 'b', label: 'Bösewichte'),
  McChipOption<String>(value: 'c', label: _german),
  McChipOption<String>(value: 'd', label: 'Außerirdische'),
];

Widget _page(
  Widget body, {
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
}) => MaterialApp(
  theme: McTheme.of(variant).copyWith(platform: TargetPlatform.iOS),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      highContrast:
          variant == McThemeVariant.highContrast ||
          variant == McThemeVariant.highContrastDark,
    ),
    child: app!,
  ),
  home: Scaffold(body: body),
);

SemanticsData _data(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

/// Holds a value the way an owning feature would, and rebuilds on change.
class _Holder<T> extends StatefulWidget {
  const _Holder({required this.initial, required this.builder, super.key});

  final T initial;
  final Widget Function(T value, ValueChanged<T> set) builder;

  @override
  State<_Holder<T>> createState() => _HolderState<T>();
}

class _HolderState<T> extends State<_Holder<T>> {
  late T value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(value, (v) => setState(() => value = v));
}

double _contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
}

McStepper _stepper({
  required int value,
  ValueChanged<int>? onChanged,
  int min = 0,
  int max = 5,
  int step = 1,
}) => McStepper(
  value: value,
  onChanged: onChanged,
  label: 'Quantity',
  decreaseLabel: 'Decrease quantity',
  increaseLabel: 'Increase quantity',
  min: min,
  max: max,
  step: step,
);

/// Every widget in every state.
List<Widget> _everyWidget({
  TextEditingController? text,
  TextEditingController? search,
}) {
  final t = text ?? TextEditingController(text: 'Peter Parker');
  final s = search ?? TextEditingController(text: 'spider');
  return [
    McTextField(controller: t, label: 'Name', helperText: 'Helper'),
    McTextField(
      controller: TextEditingController(),
      label: _german,
      errorText: 'Fehler: $_german',
    ),
    McTextField(
      controller: TextEditingController(),
      label: 'Off',
      enabled: false,
    ),
    McTextField(
      controller: TextEditingController(text: 'secret'),
      label: 'Password',
      obscureText: true,
      maxLength: 20,
      prefix: const Icon(Icons.lock),
      suffix: const Icon(Icons.visibility),
    ),
    McSearchField(
      controller: s,
      label: 'Search characters',
      clearLabel: 'Clear search',
    ),
    McSearchField(
      controller: TextEditingController(),
      label: 'Search characters',
      clearLabel: 'Clear search',
      enabled: false,
    ),
    McChipGroup<String>.single(
      options: _options,
      selected: 'a',
      onChanged: (_) {},
    ),
    McChipGroup<String>.multi(
      options: _options,
      selected: const {'a', 'c'},
      onChanged: (_) {},
    ),
    const McChip(label: 'Disabled', selected: false, onSelected: null),
    McSegmented(
      segments: const [
        McSegment(label: 'Alle'),
        McSegment(label: 'Favoriten'),
        McSegment(label: 'Größte'),
        McSegment(label: _german),
        McSegment(label: 'Zuletzt hinzugefügt'),
      ],
      selectedIndex: 1,
      onChanged: (_) {},
    ),
    McSegmented(
      segments: const [
        McSegment(label: 'On'),
        McSegment(label: 'Off'),
      ],
      selectedIndex: 0,
      onChanged: null,
    ),
    _stepper(value: 2, onChanged: (_) {}),
    _stepper(value: 0),
  ];
}

/// Every widget in every state, in one scrollable column.
Widget _everything() => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _everyWidget(),
    ),
  ),
);

void main() {
  setUpAll(mcLoadFonts);

  group('T-0044-AC1 no overflow', () {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'T-0044-AC1 every widget with long German labels at ${scale}x '
        'does not overflow',
        (tester) async {
          mcSetSurface(tester, 375, 2400);
          await tester.pumpWidget(_page(_everything(), scale: scale));
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('T-0044-AC1 every widget lays out in a narrow 280 pt column', (
      tester,
    ) async {
      mcSetSurface(tester, 280, 3000);
      await tester.pumpWidget(_page(_everything(), scale: 2));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'T-0044-AC1 an unbounded width (Row without Expanded) does not throw',
      (tester) async {
        mcSetSurface(tester, 375, 600);
        await tester.pumpWidget(
          _page(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  McTextField(
                    controller: TextEditingController(),
                    label: 'Name',
                  ),
                  McSearchField(
                    controller: TextEditingController(),
                    label: 'Search',
                    clearLabel: 'Clear',
                  ),
                  McChipGroup<String>.multi(
                    options: _options,
                    selected: const {},
                    onChanged: (_) {},
                  ),
                  McSegmented(
                    segments: const [
                      McSegment(label: 'One'),
                      McSegment(label: 'Two'),
                    ],
                    selectedIndex: 0,
                    onChanged: (_) {},
                  ),
                  _stepper(value: 1, onChanged: (_) {}),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(McTextField)).width,
          mcFieldUnboundedWidth,
        );
      },
    );

    testWidgets(
      'T-0044-AC1 small widgets keep their height in a loose Scaffold body',
      (tester) async {
        // A Scaffold body gives loose constraints with a tall maxHeight; a
        // widget that expands to it would be the whole screen tall.
        mcSetSurface(tester, 375, 800);
        for (final w in <Widget>[
          McSegmented(
            segments: const [
              McSegment(label: 'A'),
              McSegment(label: 'B'),
            ],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          _stepper(value: 1, onChanged: (_) {}),
          const McChip(label: 'Chip', selected: true, onSelected: null),
          McChipGroup<String>.single(
            options: _options,
            selected: 'a',
            onChanged: (_) {},
          ),
          McSearchField(
            controller: TextEditingController(),
            label: 'Search',
            clearLabel: 'Clear',
          ),
          McTextField(controller: TextEditingController(), label: 'Name'),
        ]) {
          await tester.pumpWidget(_page(w));
          final box = tester.getSize(find.byWidget(w));
          expect(
            box.height,
            lessThan(200),
            reason: '${w.runtimeType} must not stretch',
          );
        }
      },
    );

    testWidgets(
      'T-0044-AC1 a chip or segment inside a ListView does not scroll it',
      (tester) async {
        // Nothing here reveals itself, so no ancestor scroll view may move.
        mcSetSurface(tester, 375, 400);
        final controller = ScrollController(initialScrollOffset: 30);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _page(
            ListView(
              controller: controller,
              children: [
                const SizedBox(height: 100),
                McSegmented(
                  segments: const [
                    McSegment(label: 'A'),
                    McSegment(label: 'B'),
                  ],
                  selectedIndex: 0,
                  onChanged: (_) {},
                ),
                McChipGroup<String>.single(
                  options: _options,
                  selected: 'a',
                  onChanged: (_) {},
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        );
        await tester.tap(find.text('B'));
        await tester.pump();
        expect(controller.offset, 30);
      },
    );
    testWidgets('T-0044-AC1 a long stepper number scales down to fit', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        _page(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 150,
              child: McStepper(
                value: 1234567890,
                onChanged: (_) {},
                label: 'Quantity',
                decreaseLabel: 'Less',
                increaseLabel: 'More',
                max: 2000000000,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final stepper = tester.getRect(find.byType(McStepper));
      final number = tester.getRect(find.text('1234567890'));
      expect(number.width, lessThanOrEqualTo(stepper.width - 88));
    });

    testWidgets(
      'T-0044-AC1 segment labels are capped at ${McSegmented.labelMaxScale}x '
      'so five fit a phone at 3x',
      (tester) async {
        mcSetSurface(tester, 375, 600);
        await tester.pumpWidget(
          _page(
            McSegmented(
              segments: [
                for (final l in ['Alle', 'Helden', 'Größte', 'Neu', 'Mehr'])
                  McSegment(label: l),
              ],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
            scale: 3,
          ),
        );
        final text = tester.widget<Text>(find.text('Helden'));
        expect(text.textScaler!.scale(10), 10 * McSegmented.labelMaxScale);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('T-0044-AC1 intrinsic sizing', () {
    // A `LayoutBuilder` throws when an ancestor asks for intrinsic sizes
    // (IntrinsicWidth, IntrinsicHeight, AlertDialog's content).
    Map<String, Widget Function()> subjects() => {
      'McTextField': () => McTextField(
        controller: TextEditingController(text: 'abc'),
        label: 'Name',
        helperText: 'Helper',
      ),
      'McSearchField': () => McSearchField(
        controller: TextEditingController(text: 'abc'),
        label: 'Search',
        clearLabel: 'Clear',
      ),
      'McSegmented': () => McSegmented(
        segments: const [
          McSegment(label: 'Grid'),
          McSegment(label: 'List'),
        ],
        selectedIndex: 0,
        onChanged: (_) {},
      ),
      'McChipGroup': () => McChipGroup<String>.multi(
        options: _options,
        selected: const {'a'},
        onChanged: (_) {},
      ),
      'McStepper': () => _stepper(value: 2, onChanged: (_) {}),
    };

    for (final entry in [
      ('IntrinsicWidth', (Widget w) => IntrinsicWidth(child: w)),
      ('IntrinsicHeight', (Widget w) => IntrinsicHeight(child: w)),
      (
        'AlertDialog',
        (Widget w) => AlertDialog(content: w, title: const Text('Edit')),
      ),
    ]) {
      testWidgets(
        'T-0044-AC1 every input lays out under ${entry.$1} without throwing',
        (tester) async {
          mcSetSurface(tester, 375, 800);
          for (final s in subjects().entries) {
            await tester.pumpWidget(_page(Center(child: entry.$2(s.value()))));
            expect(
              tester.takeException(),
              isNull,
              reason: '${s.key} under ${entry.$1}',
            );
          }
        },
      );
    }

    testWidgets(
      'T-0044-AC1 segmented under IntrinsicWidth keeps equal cells',
      (tester) async {
        await tester.pumpWidget(
          _page(
            Center(
              child: IntrinsicWidth(
                child: McSegmented(
                  segments: const [
                    McSegment(label: 'A'),
                    McSegment(label: 'Much longer'),
                  ],
                  selectedIndex: 0,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        final a = tester.getSize(find.widgetWithText(InkWell, 'A')).width;
        final b = tester
            .getSize(find.widgetWithText(InkWell, 'Much longer'))
            .width;
        expect(a, closeTo(b, 0.01));
        expect(a, greaterThan(60));
      },
    );

    testWidgets('T-0044-AC1 a text field under IntrinsicWidth is 280 pt wide', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          Center(
            child: IntrinsicWidth(
              child: McTextField(
                controller: TextEditingController(),
                label: 'Name',
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(McTextField)).width, 280);
    });

    testWidgets(
      'T-0044-AC1 the drawn chip pill, not the 44 pt box, takes the ripple',
      (tester) async {
        final seen = <bool>[];
        await tester.pumpWidget(
          _page(
            Center(
              child: McChip(
                label: 'Wide label',
                selected: false,
                onSelected: seen.add,
              ),
            ),
          ),
        );
        final box = tester.getRect(find.byType(McChip));
        final ink = tester.getRect(
          find.descendant(
            of: find.byType(McChip),
            matching: find.byType(InkWell),
          ),
        );
        expect(box.height, greaterThanOrEqualTo(mcMinTapTarget));
        expect(ink.height, lessThan(mcMinTapTarget));
        // A tap in the strip above the pill still selects.
        await tester.tapAt(Offset(box.center.dx, box.top + 1));
        expect(seen, [true]);
      },
    );
  });

  group('T-0044-AC2 behaviour', () {
    testWidgets(
      'T-0044-AC2 search clear button appears only with text and clears',
      (tester) async {
        final c = TextEditingController();
        final changes = <String>[];
        await tester.pumpWidget(
          _page(
            McSearchField(
              controller: c,
              label: 'Search characters',
              clearLabel: 'Clear search',
              onChanged: changes.add,
            ),
          ),
        );
        final clear = find.bySemanticsLabel('Clear search');
        expect(clear, findsNothing);
        await tester.enterText(find.byType(TextField), 'hulk');
        await tester.pump();
        expect(clear, findsOneWidget);
        expect(changes, ['hulk']);
        // Focus is elsewhere when the button is pressed: clearing brings it
        // back into the field.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(clear);
        await tester.pump();
        expect(c.text, '');
        expect(changes, ['hulk', '']);
        expect(clear, findsNothing);
        // The focus stays in the field after clearing.
        expect(
          tester
              .state<EditableTextState>(find.byType(EditableText))
              .widget
              .focusNode
              .hasFocus,
          isTrue,
        );
      },
    );

    testWidgets(
      'T-0044-AC2 search field submits and reacts to the controller',
      (
        tester,
      ) async {
        final c = TextEditingController();
        final submitted = <String>[];
        final changes = <String>[];
        await tester.pumpWidget(
          _page(
            McSearchField(
              controller: c,
              label: 'Search',
              clearLabel: 'Clear',
              autofocus: true,
              onChanged: changes.add,
              onSubmitted: submitted.add,
            ),
          ),
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'thor');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(submitted, ['thor']);
        // An external change updates the UI (the clear button) and calls no
        // callback: no feedback loop.
        changes.clear();
        c.text = '';
        await tester.pump();
        expect(find.bySemanticsLabel('Clear'), findsNothing);
        c.text = 'loki';
        await tester.pump();
        expect(find.text('loki'), findsOneWidget);
        expect(find.bySemanticsLabel('Clear'), findsOneWidget);
        expect(changes, isEmpty);
        expect(
          tester.widget<TextField>(find.byType(TextField)).textInputAction,
          TextInputAction.search,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).autofocus,
          isTrue,
        );
      },
    );

    testWidgets('T-0044-AC2 text field shows a prefix and a tappable suffix', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _page(
          McTextField(
            controller: TextEditingController(),
            label: 'Password',
            prefix: const Icon(Icons.lock, key: ValueKey('prefix')),
            suffix: McIconButton(
              icon: Icons.visibility,
              semanticLabel: 'Show password',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('prefix')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Show password'));
      expect(taps, 1);
    });

    testWidgets(
      'T-0044-AC2 text field is controlled, reports user edits only',
      (
        tester,
      ) async {
        final c = TextEditingController(text: 'one');
        final changes = <String>[];
        await tester.pumpWidget(
          _page(
            McTextField(controller: c, label: 'Name', onChanged: changes.add),
          ),
        );
        expect(find.text('one'), findsOneWidget);
        c.text = 'two';
        await tester.pump();
        expect(find.text('two'), findsOneWidget);
        expect(changes, isEmpty);
        await tester.enterText(find.byType(TextField), 'three');
        expect(changes, ['three']);
        expect(c.text, 'three');
      },
    );

    testWidgets(
      'T-0044-AC2 text field shows helper, error replaces it, counter, '
      'obscure, action',
      (tester) async {
        final c = TextEditingController(text: 'abc');
        Widget field({String? error}) => _page(
          McTextField(
            controller: c,
            label: 'Password',
            helperText: 'At least 8 characters',
            errorText: error,
            obscureText: true,
            maxLength: 10,
            textInputAction: TextInputAction.done,
          ),
        );
        await tester.pumpWidget(field());
        expect(find.text('At least 8 characters'), findsOneWidget);
        expect(find.text('3/10'), findsOneWidget);
        await tester.pumpWidget(field(error: 'Too short'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Too short'), findsOneWidget);
        expect(find.text('At least 8 characters'), findsNothing);
        final tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.obscureText, isTrue);
        expect(tf.textInputAction, TextInputAction.done);
        // The limit stops typing.
        await tester.enterText(find.byType(TextField), 'x' * 20);
        expect(c.text.length, 10);
      },
    );

    testWidgets('T-0044-AC2 a disabled text field takes no input', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _page(
          McTextField(
            controller: TextEditingController(),
            label: 'Off',
            enabled: false,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(changes, isEmpty);
    });

    testWidgets(
      'T-0044-AC2 single-select chip group deselects the previous chip',
      (tester) async {
        await tester.pumpWidget(
          _page(
            _Holder<String?>(
              initial: 'a',
              builder: (value, set) => McChipGroup<String>.single(
                options: _options,
                selected: value,
                onChanged: set,
              ),
            ),
          ),
        );
        bool selected(String label) =>
            _data(
              tester,
              find.bySemanticsLabel(label),
            ).flagsCollection.isSelected ==
            Tristate.isTrue;
        expect(selected('Helden'), isTrue);
        await tester.tap(find.text('Bösewichte'));
        await tester.pump();
        expect(selected('Helden'), isFalse);
        expect(selected('Bösewichte'), isTrue);
        // Tapping the selected chip keeps it (no deselect by default).
        await tester.tap(find.text('Bösewichte'));
        await tester.pump();
        expect(selected('Bösewichte'), isTrue);
      },
    );

    testWidgets('T-0044-AC2 single-select allowDeselect clears the selection', (
      tester,
    ) async {
      final seen = <String?>[];
      await tester.pumpWidget(
        _page(
          _Holder<String?>(
            initial: 'a',
            builder: (value, set) => McChipGroup<String>.single(
              options: _options,
              selected: value,
              allowDeselect: true,
              onChanged: (v) {
                seen.add(v);
                set(v);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Helden'));
      await tester.pump();
      expect(seen, [null]);
      expect(
        _data(
          tester,
          find.bySemanticsLabel('Helden'),
        ).flagsCollection.isSelected,
        Tristate.isFalse,
      );
    });

    testWidgets(
      'T-0044-AC2 multi-select chip group toggles and copies the set',
      (
        tester,
      ) async {
        const initial = <String>{'a'};
        final seen = <Set<String>>[];
        await tester.pumpWidget(
          _page(
            _Holder<Set<String>>(
              initial: initial,
              builder: (value, set) => McChipGroup<String>.multi(
                options: _options,
                selected: value,
                onChanged: (v) {
                  seen.add(v);
                  set(v);
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Bösewichte'));
        await tester.pump();
        await tester.tap(find.text('Helden'));
        await tester.pump();
        expect(seen, [
          {'a', 'b'},
          {'b'},
        ]);
        expect(initial, {'a'}, reason: 'the set passed in is never mutated');
      },
    );

    testWidgets('T-0044-AC2 a chip group with no handler is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          McChipGroup<String>.single(
            options: _options,
            selected: 'a',
            onChanged: null,
          ),
        ),
      );
      expect(
        _data(
          tester,
          find.bySemanticsLabel('Helden'),
        ).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.pumpWidget(
        _page(
          McChipGroup<String>.multi(
            options: _options,
            selected: const {},
            onChanged: null,
          ),
        ),
      );
      expect(
        _data(
          tester,
          find.bySemanticsLabel('Helden'),
        ).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    });

    testWidgets('T-0044-AC2 a lone chip reports the value it would take', (
      tester,
    ) async {
      final seen = <bool>[];
      Widget chip(bool selected) => _page(
        McChip(label: 'Filter', selected: selected, onSelected: seen.add),
      );
      await tester.pumpWidget(chip(false));
      await tester.tap(find.text('Filter'));
      await tester.pumpWidget(chip(true));
      await tester.tap(find.text('Filter'));
      expect(seen, [true, false]);
    });

    testWidgets(
      'T-0044-AC2 stepper clamps at min and max and disables buttons',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _page(
            _Holder<int>(
              initial: 1,
              builder: (value, set) => _stepper(
                value: value,
                onChanged: set,
                min: 0,
                max: 3,
                step: 2,
              ),
            ),
          ),
        );
        final dec = find.bySemanticsLabel('Decrease quantity');
        final inc = find.bySemanticsLabel('Increase quantity');
        bool enabled(Finder f) =>
            _data(tester, f).flagsCollection.isEnabled == Tristate.isTrue;
        expect(find.text('1'), findsOneWidget);
        expect(enabled(dec) && enabled(inc), isTrue);
        await tester.tap(inc);
        await tester.pump();
        expect(find.text('3'), findsOneWidget, reason: '1 + 2 = 3, the max');
        expect(enabled(inc), isFalse);
        await tester.tap(inc, warnIfMissed: false);
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        await tester.tap(dec);
        await tester.pump();
        expect(find.text('1'), findsOneWidget);
        await tester.tap(dec);
        await tester.pump();
        expect(find.text('0'), findsOneWidget, reason: '1 - 2 clamps to min 0');
        expect(enabled(dec), isFalse);
        expect(enabled(inc), isTrue);
      },
    );

    testWidgets('T-0044-AC2 stepper with no handler is disabled and a value '
        'outside the range steps back into it', (tester) async {
      await tester.pumpWidget(_page(_stepper(value: 2)));
      for (final label in ['Decrease quantity', 'Increase quantity']) {
        expect(
          _data(tester, find.bySemanticsLabel(label)).flagsCollection.isEnabled,
          Tristate.isFalse,
        );
      }
      final seen = <int>[];
      await tester.pumpWidget(
        _page(_stepper(value: 9, onChanged: seen.add, max: 5)),
      );
      expect(find.text('9'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Decrease quantity'));
      expect(seen, [5]);
      await tester.pumpWidget(
        _page(
          McStepper(
            value: 7,
            onChanged: seen.add,
            label: 'Quantity',
            decreaseLabel: 'Less',
            increaseLabel: 'More',
            valueText: (v) => '$v items',
          ),
        ),
      );
      expect(find.text('7 items'), findsOneWidget);
    });

    testWidgets('T-0044-AC2 segmented reports the tapped index', (
      tester,
    ) async {
      final seen = <int>[];
      await tester.pumpWidget(
        _page(
          _Holder<int>(
            initial: 0,
            builder: (value, set) => McSegmented(
              segments: const [
                McSegment(label: 'One', key: ValueKey('s0')),
                McSegment(label: 'Two', key: ValueKey('s1')),
                McSegment(label: 'Three', key: ValueKey('s2')),
              ],
              selectedIndex: value,
              onChanged: (i) {
                seen.add(i);
                set(i);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Three'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('s1')));
      await tester.pump();
      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(seen, [2, 1, 1], reason: 'the selected segment reports too');
      expect(
        _data(tester, find.bySemanticsLabel('Two')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        _data(
          tester,
          find.bySemanticsLabel('Three'),
        ).flagsCollection.isSelected,
        Tristate.isFalse,
      );
    });

    testWidgets('T-0044-AC2 a disabled segmented control reports nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          McSegmented(
            segments: [
              McSegment(label: 'One'),
              McSegment(label: 'Two'),
            ],
            selectedIndex: 0,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('Two'));
      expect(
        _data(tester, find.bySemanticsLabel('Two')).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    });

    testWidgets(
      'T-0044-AC2 an external value change updates every widget without '
      'calling back',
      (tester) async {
        var calls = 0;
        late StateSetter set;
        var chip = 'a';
        var segment = 0;
        var count = 1;
        final c = TextEditingController();
        await tester.pumpWidget(
          _page(
            StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return Column(
                  children: [
                    McChipGroup<String>.single(
                      options: _options,
                      selected: chip,
                      onChanged: (_) => calls++,
                    ),
                    McSegmented(
                      segments: const [
                        McSegment(label: 'One'),
                        McSegment(label: 'Two'),
                      ],
                      selectedIndex: segment,
                      onChanged: (_) => calls++,
                    ),
                    _stepper(value: count, onChanged: (_) => calls++),
                    McTextField(
                      controller: c,
                      label: 'Name',
                      onChanged: (_) => calls++,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        set(() {
          chip = 'b';
          segment = 1;
          count = 4;
        });
        c.text = 'new';
        await tester.pump();
        bool sel(String l) =>
            _data(
              tester,
              find.bySemanticsLabel(l),
            ).flagsCollection.isSelected ==
            Tristate.isTrue;
        expect(sel('Bösewichte'), isTrue);
        expect(sel('Helden'), isFalse);
        expect(sel('Two'), isTrue);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('new'), findsOneWidget);
        expect(calls, 0);
      },
    );
  });

  group('T-0044-AC3 semantics', () {
    testWidgets('T-0044-AC3 text field has a label and announces its error', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Widget field({String? error}) => _page(
        McTextField(
          controller: TextEditingController(),
          label: 'Email',
          helperText: 'We never share it',
          errorText: error,
        ),
      );
      await tester.pumpWidget(field());
      var data = _data(tester, find.bySemanticsLabel('Email'));
      expect(data.flagsCollection.isTextField, isTrue);
      expect(find.bySemanticsLabel('Enter a valid email'), findsNothing);
      await tester.pumpWidget(field(error: 'Enter a valid email'));
      await tester.pump(const Duration(seconds: 1));
      data = _data(tester, find.bySemanticsLabel('Email'));
      expect(data.flagsCollection.isTextField, isTrue);
      // The error is a node of its own, in a live region: it is announced
      // when it appears.
      final error = _data(tester, find.bySemanticsLabel('Enter a valid email'));
      expect(error.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('T-0044-AC3 search field is a labelled text field', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(
          McSearchField(
            controller: TextEditingController(text: 'x'),
            label: 'Search characters',
            clearLabel: 'Clear search',
          ),
        ),
      );
      final data = _data(tester, find.bySemanticsLabel('Search characters'));
      expect(data.flagsCollection.isTextField, isTrue);
      final clear = _data(tester, find.bySemanticsLabel('Clear search'));
      expect(clear.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('T-0044-AC3 chips are buttons with a selected state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(
          Column(
            children: [
              McChip(label: 'On', selected: true, onSelected: (_) {}),
              McChip(label: 'Off', selected: false, onSelected: (_) {}),
              const McChip(label: 'Dead', selected: false, onSelected: null),
              McChipGroup<String>.single(
                options: const [McChipOption(value: 'x', label: 'Solo')],
                selected: 'x',
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      final on = _data(tester, find.bySemanticsLabel('On'));
      final off = _data(tester, find.bySemanticsLabel('Off'));
      final dead = _data(tester, find.bySemanticsLabel('Dead'));
      expect(on.flagsCollection.isButton, isTrue);
      expect(on.flagsCollection.isSelected, Tristate.isTrue);
      expect(off.flagsCollection.isSelected, Tristate.isFalse);
      expect(on.hasAction(SemanticsAction.tap), isTrue);
      expect(dead.flagsCollection.isEnabled, Tristate.isFalse);
      expect(dead.hasAction(SemanticsAction.tap), isFalse);
      expect(
        _data(
          tester,
          find.bySemanticsLabel('Solo'),
        ).flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
      );
      expect(on.flagsCollection.isInMutuallyExclusiveGroup, isFalse);
      handle.dispose();
    });

    testWidgets('T-0044-AC3 segments are buttons in an exclusive group with '
        'a selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(
          McSegmented(
            segments: const [
              McSegment(label: 'One'),
              McSegment(label: 'Two'),
            ],
            selectedIndex: 1,
            onChanged: (_) {},
          ),
        ),
      );
      final one = _data(tester, find.bySemanticsLabel('One'));
      final two = _data(tester, find.bySemanticsLabel('Two'));
      expect(two.flagsCollection.isSelected, Tristate.isTrue);
      expect(one.flagsCollection.isSelected, Tristate.isFalse);
      expect(one.flagsCollection.isButton, isTrue);
      expect(one.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(one.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets(
      'T-0044-AC3 stepper buttons are named increase and decrease, the group '
      'carries the value',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _page(_stepper(value: 3, onChanged: (_) {})),
        );
        final group = _data(tester, find.bySemanticsLabel('Quantity'));
        expect(group.value, '3');
        final dec = _data(tester, find.bySemanticsLabel('Decrease quantity'));
        final inc = _data(tester, find.bySemanticsLabel('Increase quantity'));
        expect(dec.flagsCollection.isButton, isTrue);
        expect(inc.flagsCollection.isButton, isTrue);
        expect(dec.hasAction(SemanticsAction.tap), isTrue);
        // The drawn number is not a second node: the value is read once.
        expect(find.bySemanticsLabel('3'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('T-0044-AC3 tap targets hold when the text is scaled down', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        _page(
          Column(
            children: [
              McChip(label: 'x', selected: false, onSelected: (_) {}),
              McSegmented(
                segments: const [
                  McSegment(label: 'A'),
                  McSegment(label: 'B'),
                ],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ],
          ),
          scale: 0.5,
        ),
      );
      for (final f in [
        find.byType(McChip),
        find.widgetWithText(InkWell, 'A'),
        find.widgetWithText(InkWell, 'B'),
      ]) {
        final size = tester.getSize(f);
        expect(
          size.width >= mcMinTapTarget && size.height >= mcMinTapTarget,
          isTrue,
          reason: '$f is $size at 0.5x',
        );
      }
    });

    // The platform's contrast guideline skips text fields, so the colours of
    // the label, hint, helper, error, counter and the typed text are checked
    // against the field's fill here, in every theme.
    for (final variant in McThemeVariant.values) {
      testWidgets('T-0044-AC3 text field colours reach 4.5:1 ${variant.name}', (
        tester,
      ) async {
        for (final enabled in [true, false]) {
          for (final error in [null, 'Fehler']) {
            await tester.pumpWidget(
              _page(
                Column(
                  children: [
                    McTextField(
                      controller: TextEditingController(),
                      label: 'Name',
                      hint: 'Hint',
                      helperText: 'Helper',
                      errorText: error,
                      maxLength: 10,
                      enabled: enabled,
                    ),
                    McSearchField(
                      controller: TextEditingController(),
                      label: 'Search',
                      clearLabel: 'Clear',
                      enabled: enabled,
                    ),
                  ],
                ),
                variant: variant,
              ),
            );
            await tester.pumpAndSettle();
            for (final d in tester.widgetList<InputDecorator>(
              find.byType(InputDecorator),
            )) {
              final fill = d.decoration.fillColor!;
              final colours = {
                'label': d.decoration.labelStyle?.color,
                'floatingLabel': d.decoration.floatingLabelStyle?.color,
                'hint': d.decoration.hintStyle?.color,
                'helper': d.decoration.helperStyle?.color,
                'counter': d.decoration.counterStyle?.color,
                'text': d.baseStyle?.color,
              };
              for (final e in colours.entries) {
                if (e.value == null) {
                  continue;
                }
                expect(
                  _contrast(e.value!, fill),
                  greaterThanOrEqualTo(4.5),
                  reason:
                      '${e.key} on the fill (enabled $enabled, error $error)',
                );
              }
            }
            for (final t in tester.widgetList<Text>(find.text('Fehler'))) {
              expect(
                _contrast(
                  t.style!.color!,
                  tester
                      .widgetList<InputDecorator>(find.byType(InputDecorator))
                      .first
                      .decoration
                      .fillColor!,
                ),
                greaterThanOrEqualTo(4.5),
                reason: 'error text on the fill',
              );
            }
          }
        }
      });
    }

    testWidgets('T-0044-AC3 every tap target is at least 44 pt', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 900);
      await tester.pumpWidget(
        _page(
          SingleChildScrollView(
            child: Column(
              children: [
                McChip(label: 'x', selected: false, onSelected: (_) {}),
                McSegmented(
                  segments: const [
                    McSegment(label: 'A'),
                    McSegment(label: 'B'),
                  ],
                  selectedIndex: 0,
                  onChanged: (_) {},
                ),
                _stepper(value: 2, onChanged: (_) {}),
                McSearchField(
                  controller: TextEditingController(text: 'x'),
                  label: 'Search',
                  clearLabel: 'Clear',
                ),
                McTextField(controller: TextEditingController(), label: 'Name'),
              ],
            ),
          ),
        ),
      );
      final targets = <Finder>[
        find.byType(McChip),
        find.widgetWithText(InkWell, 'A'),
        find.widgetWithText(InkWell, 'B'),
        find.bySemanticsLabel('Decrease quantity'),
        find.bySemanticsLabel('Increase quantity'),
        find.bySemanticsLabel('Clear'),
        find.byType(TextField),
      ];
      for (final f in targets) {
        final size = tester.getSize(f.first);
        expect(
          size.width >= mcMinTapTarget && size.height >= mcMinTapTarget,
          isTrue,
          reason: '$f is $size',
        );
      }
    });

    for (final variant in McThemeVariant.values) {
      testWidgets(
        'T-0044-AC3 meetsGuideline (tap target, label, contrast) '
        '${variant.name}',
        (tester) async {
          final handle = tester.ensureSemantics();
          mcSetSurface(tester, 375, 2000);
          // One widget per page: the guidelines read pixels by semantics
          // rect, and a tall mixed page made them sample the wrong region.
          final widgets = _everyWidget();
          for (final w in widgets) {
            await tester.pumpWidget(
              _page(
                Padding(padding: const EdgeInsets.all(16), child: w),
                variant: variant,
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          handle.dispose();
        },
      );
    }

    testWidgets(
      'T-0044-AC3 disabled outlines are not dimmed in high contrast',
      (
        tester,
      ) async {
        Future<Color> outline(McThemeVariant v) async {
          await tester.pumpWidget(
            _page(
              McSegmented(
                segments: const [
                  McSegment(label: 'A'),
                  McSegment(label: 'B'),
                ],
                selectedIndex: 0,
                onChanged: null,
              ),
              variant: v,
            ),
          );
          await tester.pumpAndSettle();
          final box = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(McSegmented),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          return ((box.decoration as BoxDecoration).border! as Border)
              .top
              .color;
        }

        expect(
          await outline(McThemeVariant.highContrast),
          McPalette.highContrast.outline,
        );
        expect(
          await outline(McThemeVariant.light),
          McPalette.light.outline.withAlpha(110),
        );
      },
    );
  });
}
