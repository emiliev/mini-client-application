import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _german =
    'Donaudampfschifffahrtsgesellschaftskapitänsmützenabzeichen-Beschreibung';

const _homeKey = Key('test.home');
const _nestedHomeKey = Key('test.nested_home');
final _nestedKey = GlobalKey<NavigatorState>();

Widget _app(
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

/// An app with a nested navigator in its top 300 pt and the home below.
Widget _nestedApp({
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
}) => _app(
  Column(
    children: [
      SizedBox(
        height: 300,
        child: Navigator(
          key: _nestedKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Center(key: _nestedHomeKey),
          ),
        ),
      ),
      const Expanded(child: Center(key: _homeKey)),
    ],
  ),
  variant: variant,
  scale: scale,
);

Widget _plain({
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
}) => _app(
  const Center(key: _homeKey),
  variant: variant,
  scale: scale,
);

BuildContext _ctx(WidgetTester tester, [Key key = _homeKey]) =>
    tester.element(find.byKey(key));

NavigatorState _navigatorOf(WidgetTester tester, Finder f) =>
    Navigator.of(tester.element(f.first));

NavigatorState _root(WidgetTester tester) =>
    Navigator.of(_ctx(tester), rootNavigator: true);

Rect _screen(WidgetTester tester) =>
    Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

Future<void> _tapBarrier(WidgetTester tester) async {
  await tester.tapAt(const Offset(2, 2));
  await tester.pumpAndSettle();
}

List<SemanticsNode> _nodes(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void visit(SemanticsNode n) {
    out.add(n);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

Iterable<SemanticsNode> _labelled(WidgetTester tester, String label) =>
    _nodes(tester).where((n) => n.getSemanticsData().label == label);

SemanticsData _node(WidgetTester tester, String label) {
  final found = _labelled(tester, label).toList();
  expect(found, hasLength(1), reason: 'one semantics node labelled "$label"');
  return found.single.getSemanticsData();
}

/// The title is read once: one node carries it, as the heading and as the
/// route's name, inside a node that scopes the route.
void _expectTitleOnce(WidgetTester tester, String title) {
  final nodes = _labelled(tester, title).toList();
  expect(nodes, hasLength(1), reason: 'exactly one node reads "$title"');
  final flags = nodes.single.getSemanticsData().flagsCollection;
  expect(flags.isHeader, isTrue, reason: 'the title is a heading');
  expect(flags.namesRoute, isTrue, reason: 'and it names the route');
  var scoped = false;
  for (SemanticsNode? n = nodes.single.parent; n != null; n = n.parent) {
    scoped = scoped || n.getSemanticsData().flagsCollection.scopesRoute;
  }
  expect(scoped, isTrue, reason: 'the title sits inside a node that scopes it');
}

Future<void> _confirm(
  WidgetTester tester, {
  bool destructive = false,
  bool? useRootNavigator,
  BuildContext? context,
  String title = 'Delete comic?',
  String message = 'It will be removed from your library.',
}) async {
  // The default of `useRootNavigator` is under test: pass it only when asked.
  final answer = useRootNavigator == null
      ? showMcConfirm(
          context ?? _ctx(tester),
          title: title,
          message: message,
          confirmLabel: 'Delete',
          cancelLabel: 'Keep',
          destructive: destructive,
          barrierLabel: 'Close dialog',
        )
      : showMcConfirm(
          context ?? _ctx(tester),
          title: title,
          message: message,
          confirmLabel: 'Delete',
          cancelLabel: 'Keep',
          destructive: destructive,
          useRootNavigator: useRootNavigator,
          barrierLabel: 'Close dialog',
        );
  await tester.pumpAndSettle();
  // The caller awaits the answer after acting on the dialog.
  _pending = answer;
}

Future<bool>? _pending;

const _options = [
  McChoiceOption<String>(
    value: 'light',
    label: 'Light',
    icon: Icons.light_mode,
  ),
  McChoiceOption<String>(value: 'dark', label: 'Dark', icon: Icons.dark_mode),
  McChoiceOption<String>(value: 'system', label: 'Follow the system'),
];

Future<Future<String?>> _openChoice(
  WidgetTester tester, {
  String? selected,
  bool? useRootNavigator,
  BuildContext? context,
  List<McChoiceOption<String>> options = _options,
}) async {
  final answer = useRootNavigator == null
      ? showMcChoiceSheet<String>(
          context ?? _ctx(tester),
          title: 'Appearance',
          dismissLabel: 'Close sheet',
          options: options,
          selected: selected,
        )
      : showMcChoiceSheet<String>(
          context ?? _ctx(tester),
          title: 'Appearance',
          dismissLabel: 'Close sheet',
          options: options,
          selected: selected,
          useRootNavigator: useRootNavigator,
        );
  await tester.pumpAndSettle();
  return answer;
}

List<McMenuItem<String>> _menuItems({bool long = false}) => [
  McMenuItem(value: 'edit', label: long ? _german : 'Edit', icon: Icons.edit),
  const McMenuItem(
    value: 'share',
    label: 'Share',
    icon: Icons.share,
    enabled: false,
  ),
  McMenuItem(
    value: 'delete',
    label: long ? 'Löschen: $_german' : 'Delete',
    icon: Icons.delete,
    destructive: true,
  ),
];

Widget _menuApp(
  List<String> picked, {
  bool long = false,
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
}) => _app(
  Align(
    alignment: Alignment.topRight,
    child: McMenuButton<String>(
      items: _menuItems(long: long),
      onSelected: picked.add,
      semanticLabel: 'More actions',
    ),
  ),
  variant: variant,
  scale: scale,
);

void main() {
  // ---------------------------------------------------------------- AC2
  group('T-0058-AC2 showMcConfirm', () {
    testWidgets('T-0058-AC2 confirm answers true', (tester) async {
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      expect(find.byType(McDialog), findsOneWidget);
      await tester.tap(find.byKey(mcConfirmButtonKey));
      await tester.pumpAndSettle();
      expect(await _pending, isTrue);
      expect(find.byType(McDialog), findsNothing);
    });

    testWidgets('T-0058-AC2 cancel answers false', (tester) async {
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      await tester.tap(find.byKey(mcCancelButtonKey));
      await tester.pumpAndSettle();
      expect(await _pending, isFalse);
    });

    testWidgets('T-0058-AC2 a barrier tap answers false, not null', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      await _tapBarrier(tester);
      expect(find.byType(McDialog), findsNothing);
      expect(await _pending, isFalse);
    });

    testWidgets('T-0058-AC2 system back answers false, not null', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(McDialog), findsNothing);
      expect(await _pending, isFalse);
    });

    testWidgets(
      'T-0058-AC2 destructive draws the confirm outlined in the error colour '
      'and still answers true',
      (tester) async {
        await tester.pumpWidget(_plain());
        await _confirm(tester, destructive: true);
        final p = McPalette.light;
        final button = tester.widget<OutlinedButton>(
          find.byKey(mcConfirmButtonKey),
        );
        expect(button.style!.foregroundColor!.resolve({}), p.error);
        expect(button.style!.side!.resolve({})!.color, p.error);
        await tester.tap(find.byKey(mcConfirmButtonKey));
        await tester.pumpAndSettle();
        expect(await _pending, isTrue);
      },
    );

    testWidgets('T-0058-AC2 a plain confirm is filled in the primary colour', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(mcConfirmButtonKey),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        button.style!.backgroundColor!.resolve({}),
        McPalette.light.primary,
      );
      expect(
        find.descendant(
          of: find.byKey(mcCancelButtonKey),
          matching: find.byType(TextButton),
        ),
        findsOneWidget,
      );
    });
  });

  group('T-0058-AC2 showMcDialog', () {
    testWidgets('T-0058-AC2 answers the popped value and null on dismiss', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      Future<String?> open({bool dismissible = true}) {
        final f = showMcDialog<String>(
          _ctx(tester),
          barrierDismissible: dismissible,
          builder: (c) => McDialog(
            title: 'Pick',
            body: const Text('One of three'),
            actions: [
              McDialogAction(
                label: 'A',
                kind: McDialogActionKind.primary,
                onPressed: () => Navigator.of(c).pop('a'),
              ),
              McDialogAction(
                label: 'B',
                onPressed: () => Navigator.of(c).pop('b'),
              ),
              McDialogAction(
                label: 'Wipe',
                kind: McDialogActionKind.destructive,
                onPressed: () => Navigator.of(c).pop('wipe'),
              ),
            ],
          ),
        );
        return f;
      }

      var answer = open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(await answer, 'b');

      answer = open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wipe'));
      await tester.pumpAndSettle();
      expect(await answer, 'wipe');

      answer = open();
      await tester.pumpAndSettle();
      await _tapBarrier(tester);
      expect(await answer, isNull);

      answer = open(dismissible: false);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(McDialog), findsOneWidget, reason: 'not dismissible');
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(await answer, 'a');
    });

    testWidgets('T-0058-AC2 a disabled action takes no tap', (tester) async {
      await tester.pumpWidget(_plain());
      final answer = showMcDialog<String>(
        _ctx(tester),
        builder: (c) => McDialog(
          title: 'Wait',
          body: const Text('Busy'),
          actions: [
            const McDialogAction(
              label: 'Go',
              kind: McDialogActionKind.primary,
              onPressed: null,
            ),
            const McDialogAction(
              label: 'Wipe',
              kind: McDialogActionKind.destructive,
              onPressed: null,
            ),
            McDialogAction(
              label: 'Close',
              onPressed: () => Navigator.of(c).pop('closed'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.tap(find.text('Wipe'));
      await tester.pumpAndSettle();
      expect(find.byType(McDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await answer, 'closed');
    });

    testWidgets('T-0058-AC2 a dialog needs one to three actions', (
      tester,
    ) async {
      expect(
        () => McDialog(title: 't', body: const SizedBox(), actions: const []),
        throwsAssertionError,
      );
      expect(
        () => McDialog(
          title: 't',
          body: const SizedBox(),
          actions: List.filled(
            4,
            const McDialogAction(label: 'x', onPressed: null),
          ),
        ),
        throwsAssertionError,
      );
    });
  });

  group('T-0058-AC2 showMcChoiceSheet', () {
    testWidgets('T-0058-AC2 answers the tapped value', (tester) async {
      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(await answer, 'dark');
      expect(find.byType(McSheet), findsNothing);
    });

    testWidgets('T-0058-AC2 tapping the current option answers it again', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(await answer, 'light');
    });

    testWidgets('T-0058-AC2 a swipe down answers null', (tester) async {
      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      await tester.drag(find.byType(McSheet), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.byType(McSheet), findsNothing);
      expect(await answer, isNull);
    });

    testWidgets('T-0058-AC2 a barrier tap answers null', (tester) async {
      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      await _tapBarrier(tester);
      expect(find.byType(McSheet), findsNothing);
      expect(await answer, isNull);
    });

    testWidgets('T-0058-AC2 system back answers null', (tester) async {
      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await answer, isNull);
    });

    testWidgets('T-0058-AC2 the handle dismisses the sheet', (tester) async {
      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      await tester.tap(find.bySemanticsLabel('Close sheet').first);
      await tester.pumpAndSettle();
      expect(find.byType(McSheet), findsNothing);
      expect(await answer, isNull);
    });

    testWidgets('T-0058-AC2 shows a check on the current option only', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      await _openChoice(tester, selected: 'dark');
      final check = find.byIcon(Icons.check);
      expect(check, findsOneWidget);
      final row = find.ancestor(of: check, matching: find.byType(InkWell));
      expect(
        find.descendant(of: row, matching: find.text('Dark')),
        findsOneWidget,
        reason: 'the check is on the Dark row',
      );
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      await _openChoice(tester);
      expect(find.byIcon(Icons.check), findsNothing, reason: 'nothing picked');
    });

    testWidgets('T-0058-AC2 the selected option is announced as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_plain());
      await _openChoice(tester, selected: 'dark');
      expect(
        _node(tester, 'Dark').flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        _node(tester, 'Light').flagsCollection.isSelected,
        Tristate.isFalse,
      );
      expect(_node(tester, 'Light').flagsCollection.isButton, isTrue);
      expect(_node(tester, 'Light').hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('T-0058-AC2 McMenuButton', () {
    testWidgets('T-0058-AC2 reports the picked value', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(_menuApp(picked));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(picked, ['edit']);
      expect(find.text('Edit'), findsNothing, reason: 'the menu closed');

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(picked, ['edit', 'delete']);
    });

    testWidgets('T-0058-AC2 a disabled item ignores taps and keeps the menu '
        'open', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(_menuApp(picked));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(find.text('Share'), findsOneWidget, reason: 'menu still open');
    });

    testWidgets('T-0058-AC2 dismissing the menu reports nothing', (
      tester,
    ) async {
      final picked = <String>[];
      await tester.pumpWidget(_menuApp(picked));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await _tapBarrier(tester);
      expect(find.text('Edit'), findsNothing);
      expect(picked, isEmpty);
    });

    testWidgets('T-0058-AC2 destructive and disabled rows are styled', (
      tester,
    ) async {
      await tester.pumpWidget(_menuApp([]));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      Color colorOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      final p = McPalette.light;
      expect(colorOf('Delete'), p.error);
      expect(colorOf('Share'), p.onSurfaceMuted);
      expect(colorOf('Edit'), p.onSurface);
      Color iconColor(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color!;
      expect(iconColor(Icons.delete), p.error);
      expect(iconColor(Icons.share), p.onSurfaceMuted);
    });
  });

  group('T-0058-AC2 toasts', () {
    testWidgets('T-0058-AC2 a second toast replaces the first', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      showMcToast(_ctx(tester), 'First');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First'), findsOneWidget);

      showMcToast(_ctx(tester), 'Second');
      await tester.pump();
      expect(find.text('First'), findsNothing, reason: 'replaced at once');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Second'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('T-0058-AC2 the toast action fires once', (tester) async {
      await tester.pumpWidget(_plain());
      var calls = 0;
      showMcToast(
        _ctx(tester),
        'Comic removed',
        action: McToastAction(label: 'Undo', onPressed: () => calls++),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Comic removed'), findsNothing, reason: 'it closed');
    });

    testWidgets('T-0058-AC2 a toast without an action stays 4 s, with an '
        'action 8 s', (tester) async {
      await tester.pumpWidget(_plain());
      showMcToast(_ctx(tester), 'Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);

      showMcToast(
        _ctx(tester),
        'Removed',
        action: McToastAction(label: 'Undo', onPressed: () {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Past the 4 s of a toast without an action, and past its exit
      // animation, so it would be gone by now if the action did not count.
      await tester.pump(const Duration(seconds: 4, milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Removed'), findsOneWidget, reason: 'still up at 5 s');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Removed'), findsNothing);
      expect(mcToastActionDuration, greaterThan(mcToastDuration));
    });

    testWidgets('T-0058-AC2 an explicit duration wins', (tester) async {
      await tester.pumpWidget(_plain());
      showMcToast(
        _ctx(tester),
        'Quick',
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.text('Quick'), findsNothing);
    });

    testWidgets('T-0058-AC2 the toast closes through its controller', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      final c = showMcToast(_ctx(tester), 'Hello');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      c.close();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });
  });

  group('T-0058-AC2 root and nearest navigator', () {
    testWidgets('T-0058-AC2 a dialog covers the nested navigator by default', (
      tester,
    ) async {
      mcSetSurface(tester, 400, 800);
      await tester.pumpWidget(_nestedApp());
      await _confirm(tester, context: _ctx(tester, _nestedHomeKey));
      expect(
        _navigatorOf(tester, find.byType(McDialog)),
        same(_root(tester)),
      );
      expect(_nestedKey.currentState!.canPop(), isFalse);
      expect(tester.getRect(find.byType(ModalBarrier).last), _screen(tester));
      await tester.tap(find.byKey(mcConfirmButtonKey));
      await tester.pumpAndSettle();
      expect(await _pending, isTrue);
    });

    testWidgets('T-0058-AC2 a dialog with the nearest navigator stays inside '
        'it', (tester) async {
      mcSetSurface(tester, 400, 800);
      await tester.pumpWidget(_nestedApp());
      await _confirm(
        tester,
        context: _ctx(tester, _nestedHomeKey),
        useRootNavigator: false,
      );
      expect(
        _navigatorOf(tester, find.byType(McDialog)),
        same(_nestedKey.currentState),
      );
      final barrier = tester.getRect(find.byType(ModalBarrier).last);
      expect(barrier.height, 300);
      expect(barrier.height, lessThan(_screen(tester).height));
      await tester.tap(find.byKey(mcCancelButtonKey));
      await tester.pumpAndSettle();
      expect(await _pending, isFalse);
    });

    testWidgets('T-0058-AC2 showMcDialog: root by default, nearest on '
        'request', (tester) async {
      mcSetSurface(tester, 400, 800);
      await tester.pumpWidget(_nestedApp());
      final nested = _ctx(tester, _nestedHomeKey);
      McDialog dialog(BuildContext c) => McDialog(
        title: 'T',
        body: const Text('B'),
        actions: [
          McDialogAction(label: 'OK', onPressed: () => Navigator.of(c).pop()),
        ],
      );

      var answer = showMcDialog<void>(nested, builder: dialog);
      await tester.pumpAndSettle();
      expect(
        _navigatorOf(tester, find.byType(McDialog)),
        same(_root(tester)),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await answer;

      answer = showMcDialog<void>(
        nested,
        useRootNavigator: false,
        builder: dialog,
      );
      await tester.pumpAndSettle();
      expect(
        _navigatorOf(tester, find.byType(McDialog)),
        same(_nestedKey.currentState),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await answer;
    });

    testWidgets('T-0058-AC2 a sheet: root by default, nearest on request', (
      tester,
    ) async {
      mcSetSurface(tester, 400, 800);
      await tester.pumpWidget(_nestedApp());
      final nested = _ctx(tester, _nestedHomeKey);

      var answer = showMcSheet<String>(
        nested,
        builder: (_) => const McSheet(
          title: 'Sheet',
          dismissLabel: 'Close',
          child: Text('body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_navigatorOf(tester, find.byType(McSheet)), same(_root(tester)));
      expect(tester.getRect(find.byType(ModalBarrier).last), _screen(tester));
      await _tapBarrier(tester);
      expect(await answer, isNull);

      answer = showMcSheet<String>(
        nested,
        useRootNavigator: false,
        builder: (_) => const McSheet(
          title: 'Sheet',
          dismissLabel: 'Close',
          child: Text('body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _navigatorOf(tester, find.byType(McSheet)),
        same(_nestedKey.currentState),
      );
      expect(tester.getRect(find.byType(ModalBarrier).last).height, 300);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(await answer, isNull);
    });

    testWidgets('T-0058-AC2 a choice sheet: root by default, nearest on '
        'request', (tester) async {
      mcSetSurface(tester, 400, 800);
      await tester.pumpWidget(_nestedApp());
      final nested = _ctx(tester, _nestedHomeKey);

      var answer = await _openChoice(tester, context: nested);
      expect(_navigatorOf(tester, find.byType(McSheet)), same(_root(tester)));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(await answer, 'dark');

      answer = await _openChoice(
        tester,
        context: nested,
        useRootNavigator: false,
      );
      expect(
        _navigatorOf(tester, find.byType(McSheet)),
        same(_nestedKey.currentState),
      );
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(await answer, 'light');
    });

    testWidgets('T-0058-AC2 a menu: root by default, nearest on request', (
      tester,
    ) async {
      mcSetSurface(tester, 400, 800);
      // null: the default, which must be the root navigator.
      for (final option in <bool?>[null, true, false]) {
        final root = option ?? true;
        final menu = option == null
            ? McMenuButton<String>(
                items: _menuItems(),
                onSelected: (_) {},
                semanticLabel: 'More actions',
              )
            : McMenuButton<String>(
                items: _menuItems(),
                onSelected: (_) {},
                semanticLabel: 'More actions',
                useRootNavigator: option,
              );
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                SizedBox(
                  height: 300,
                  child: Navigator(
                    key: GlobalKey<NavigatorState>(),
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Align(
                        alignment: Alignment.topRight,
                        child: menu,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        final menuNav = _navigatorOf(tester, find.text('Edit'));
        final rootNav = Navigator.of(
          tester.element(find.byTooltip('More actions')),
          rootNavigator: true,
        );
        expect(identical(menuNav, rootNav), root);
        await tester.tapAt(const Offset(2, 790));
        await tester.pumpAndSettle();
      }
    });
  });

  // ---------------------------------------------------------------- AC3
  group('T-0058-AC3 semantics', () {
    testWidgets('T-0058-AC3 a dialog names its route with the title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      _expectTitleOnce(tester, 'Delete comic?');
      for (final label in ['Delete', 'Keep']) {
        final d = _node(tester, label);
        expect(d.flagsCollection.isButton, isTrue, reason: label);
        expect(d.hasAction(SemanticsAction.tap), isTrue, reason: label);
      }
      handle.dispose();
    });

    testWidgets('T-0058-AC3 a sheet names its route and has a dismiss label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_plain());
      await _openChoice(tester, selected: 'light');
      _expectTitleOnce(tester, 'Appearance');
      final dismiss = _nodes(tester).where((n) {
        final d = n.getSemanticsData();
        return d.label == 'Close sheet' &&
            d.flagsCollection.isButton &&
            d.hasAction(SemanticsAction.tap);
      });
      expect(dismiss, isNotEmpty, reason: 'the handle is a dismiss button');
      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .where((b) => b.semanticsLabel == 'Close sheet');
      expect(barrier, hasLength(1), reason: 'the barrier says it dismisses');
      handle.dispose();
    });

    testWidgets('T-0058-AC3 a dialog barrier carries the dismiss label', (
      tester,
    ) async {
      await tester.pumpWidget(_plain());
      await _confirm(tester);
      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .where((b) => b.semanticsLabel == 'Close dialog');
      expect(barrier, hasLength(1));
    });

    testWidgets('T-0058-AC3 the toast is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_plain());
      showMcToast(_ctx(tester), 'Comic removed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final live = _nodes(tester).where((n) {
        final d = n.getSemanticsData();
        return d.flagsCollection.isLiveRegion &&
            d.label.contains('Comic removed');
      });
      expect(live, isNotEmpty);
      handle.dispose();
    });

    testWidgets('T-0058-AC3 the menu button and its rows are named', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_menuApp([]));
      final button = _node(tester, 'More actions');
      expect(button.flagsCollection.isButton, isTrue);
      expect(button.hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('More actions'), findsOneWidget);
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(
        _node(tester, 'Edit').flagsCollection.isEnabled,
        Tristate.isTrue,
      );
      expect(
        _node(tester, 'Share').flagsCollection.isEnabled,
        Tristate.isFalse,
        reason: 'a disabled row is announced as disabled',
      );
      expect(_node(tester, 'Edit').hasAction(SemanticsAction.tap), isTrue);
      expect(_node(tester, 'Share').hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('T-0058-AC3 a screen reader can open the menu and dismiss a '
        'sheet through the semantics tap action', (tester) async {
      final handle = tester.ensureSemantics();
      void semanticTap(String label) {
        final node = _labelled(tester, label).firstWhere(
          (n) => n.getSemanticsData().hasAction(SemanticsAction.tap),
        );
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
      }

      final picked = <String>[];
      await tester.pumpWidget(_menuApp(picked));
      semanticTap('More actions');
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget, reason: 'the menu opened');
      await _tapBarrier(tester);

      await tester.pumpWidget(_plain());
      final answer = await _openChoice(tester, selected: 'light');
      semanticTap('Close sheet');
      await tester.pumpAndSettle();
      expect(find.byType(McSheet), findsNothing);
      expect(await answer, isNull);
      handle.dispose();
    });

    testWidgets('T-0058-AC3 a tooltip shows on long press and on hover, and '
        'is on the child semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Center(
            child: McTooltip(
              message: 'Add to favourites',
              child: ColoredBox(
                key: Key('test.target'),
                color: Colors.red,
                child: SizedBox(width: 60, height: 60),
              ),
            ),
          ),
        ),
      );
      final target = find.byKey(const Key('test.target'));
      expect(
        tester.getSemantics(target).getSemanticsData().tooltip,
        'Add to favourites',
      );
      expect(find.text('Add to favourites'), findsNothing);

      // A plain tap shows nothing; a long press does.
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Add to favourites'), findsNothing);
      await tester.longPress(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Add to favourites'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Add to favourites'), findsNothing);

      // Hover.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Add to favourites'), findsOneWidget);
      await mouse.moveTo(const Offset(2, 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Add to favourites'), findsNothing);
      handle.dispose();
    });

    testWidgets('T-0058-AC3 every tap target is at least 44 pt', (
      tester,
    ) async {
      // Half-size text, so a minimum that held only by accident shows.
      for (final scale in [0.5, 1.0]) {
        await tester.pumpWidget(_menuApp([], scale: scale));
        final button = tester.getSize(find.byTooltip('More actions'));
        expect(button.width >= mcMinTapTarget, isTrue, reason: '$button');
        expect(button.height >= mcMinTapTarget, isTrue, reason: '$button');
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        for (final item in tester.widgetList(
          find.byType(PopupMenuItem<String>),
        )) {
          final size = tester.getSize(find.byWidget(item));
          expect(size.height >= mcMinTapTarget, isTrue, reason: '$size');
        }
        await _tapBarrier(tester);

        await tester.pumpWidget(_plain(scale: scale));
        await _confirm(tester);
        for (final key in [mcConfirmButtonKey, mcCancelButtonKey]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.height >= mcMinTapTarget, isTrue, reason: '$size');
          expect(size.width >= mcMinTapTarget, isTrue, reason: '$size');
        }
        await _tapBarrier(tester);

        // The destructive confirm is a different button: check it too.
        await _confirm(tester, destructive: true);
        final destructive = tester.getSize(find.byKey(mcConfirmButtonKey));
        expect(destructive.height >= mcMinTapTarget, isTrue);
        expect(destructive.width >= mcMinTapTarget, isTrue);
        await _tapBarrier(tester);

        await _openChoice(tester, selected: 'dark');
        for (final label in ['Light', 'Dark', 'Follow the system']) {
          final size = tester.getSize(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          );
          expect(size.height >= mcMinTapTarget, isTrue, reason: '$label $size');
        }
        final handle = tester.getSize(
          find
              .descendant(
                of: find.byType(McSheet),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(handle.height >= mcMinTapTarget, isTrue, reason: '$handle');
        await _tapBarrier(tester);

        showMcToast(
          _ctx(tester),
          'Removed',
          action: McToastAction(label: 'Undo', onPressed: () {}),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final undo = tester.getSize(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(TextButton),
          ),
        );
        expect(undo.height >= mcMinTapTarget, isTrue, reason: '$undo');
        expect(undo.width >= mcMinTapTarget, isTrue, reason: '$undo');
        await tester.pumpAndSettle(const Duration(seconds: 9));
      }
    });

    for (final variant in McThemeVariant.values) {
      for (final scenario in _scenarios.entries) {
        testWidgets(
          'T-0058-AC3 meetsGuideline (tap target, label, contrast) '
          '${scenario.key} ${variant.name}',
          (tester) async {
            final handle = tester.ensureSemantics();
            mcSetSurface(tester, 375, 667);
            await tester.pumpWidget(_scenarioApp(scenario.key, variant));
            await scenario.value(tester);
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            handle.dispose();
          },
        );
      }
    }
  });

  // ------------------------------------------------- keyboard (review round)
  group('T-0058-AC1 keyboard', () {
    const fieldKey = Key('test.sheet_field');
    const saveKey = Key('test.sheet_save');

    Future<void> openFormSheet(WidgetTester tester) async {
      unawaited(
        showMcSheet<void>(
          _ctx(tester),
          dismissLabel: 'Close',
          builder: (_) => McSheet(
            title: 'Rename list',
            dismissLabel: 'Close',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TextField(key: fieldKey),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: saveKey,
                  onPressed: () {},
                  child: const Text('Save'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () {}, child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The drawn card (McSheet itself also holds the keyboard padding).
    Finder _card() => find
        .descendant(of: find.byType(McSheet), matching: find.byType(Material))
        .first;

    void keyboard(WidgetTester tester, double height) {
      tester.view.viewInsets = FakeViewPadding(
        bottom: height * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
    }

    testWidgets('T-0058-AC1 the field and the actions stay above a 300 pt '
        'keyboard and take taps', (tester) async {
      mcSetSurface(tester, 375, 667);
      await tester.pumpWidget(_plain());
      await openFormSheet(tester);
      keyboard(tester, 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final key in [fieldKey, saveKey]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.bottom, lessThanOrEqualTo(667 - 300), reason: '$key');
        expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key');
      }
      expect(
        tester.getRect(_card()).bottom,
        lessThanOrEqualTo(667 - 300),
        reason: 'the card sits on the keyboard',
      );
      await tester.tap(find.byKey(fieldKey));
      await tester.enterText(find.byKey(fieldKey), 'Reading');
      expect(tester.takeException(), isNull);
    });

    for (final scale in [2.0, 3.0]) {
      testWidgets('T-0058-AC1 with the keyboard up at ${scale}x nothing '
          'overflows, the body scrolls and the actions are reachable', (
        tester,
      ) async {
        mcSetSurface(tester, 375, 667);
        await tester.pumpWidget(_plain(scale: scale));
        await openFormSheet(tester);
        keyboard(tester, 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(_card()).bottom,
          lessThanOrEqualTo(667 - 300),
        );
        // The body scrolls: bring the Save button into view and tap it.
        await tester.scrollUntilVisible(
          find.byKey(saveKey),
          100,
          scrollable: find
              .descendant(
                of: find.byType(McSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.byKey(saveKey).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('T-0058-AC1 without a keyboard the sheet sits at the bottom '
        'with the safe-area inset', (tester) async {
      mcSetSurface(tester, 375, 667);
      await tester.pumpWidget(_plain());
      await openFormSheet(tester);
      expect(tester.getRect(_card()).bottom, 667);
    });
  });

  // ------------------------------- dismissible (review round, T-0058-AC2/AC3)
  group('T-0058-AC2 a sheet that may not be dismissed', () {
    Future<Future<String?>> open(
      WidgetTester tester, {
      bool isDismissible = true,
      bool enableDrag = true,
    }) async {
      final answer = showMcSheet<String>(
        _ctx(tester),
        dismissLabel: 'Close',
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        builder: (_) => const McSheet(
          title: 'Busy',
          dismissLabel: 'Close',
          child: Text('Working'),
        ),
      );
      await tester.pumpAndSettle();
      return answer;
    }

    /// Taps where the handle is: the middle of the first 44 pt of the card.
    Future<void> tapHandle(WidgetTester tester) {
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(McSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      return tester.tapAt(Offset(card.center.dx, card.top + 22));
    }

    for (final (name, dismissible, drag) in [
      ('isDismissible: false', false, true),
      ('enableDrag: false', true, false),
    ]) {
      testWidgets('T-0058-AC2 with $name the handle tap, the screen reader '
          'and the barrier leave the sheet open', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_plain());
        await open(tester, isDismissible: dismissible, enableDrag: drag);

        await tapHandle(tester);
        await tester.pumpAndSettle();
        expect(find.byType(McSheet), findsOneWidget, reason: 'handle tap');

        final actions = _nodes(tester).where((n) {
          final d = n.getSemanticsData();
          return d.label == 'Close' && d.hasAction(SemanticsAction.tap);
        });
        // The barrier of an `isDismissible: false` sheet has no tap either.
        expect(
          actions.where((n) => n.getSemanticsData().flagsCollection.isButton),
          isEmpty,
          reason: 'no dismiss button for a screen reader',
        );
        if (!dismissible) {
          await tester.tapAt(const Offset(2, 2));
          await tester.pumpAndSettle();
          expect(find.byType(McSheet), findsOneWidget, reason: 'barrier tap');
        }
        handle.dispose();
      });
    }

    testWidgets('T-0058-AC2 a dismissible sheet keeps its handle', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_plain());
      final answer = await open(tester);
      expect(
        _nodes(tester).any((n) {
          final d = n.getSemanticsData();
          return d.label == 'Close' &&
              d.flagsCollection.isButton &&
              d.hasAction(SemanticsAction.tap);
        }),
        isTrue,
      );
      await tapHandle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(McSheet), findsNothing);
      expect(await answer, isNull);
      handle.dispose();
    });

    testWidgets('T-0058-AC2 a standalone McSheet keeps its handle', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              title: 'Solo',
              dismissLabel: 'Close',
              child: Text('x'),
            ),
          ),
        ),
      );
      expect(
        _nodes(tester).any((n) {
          final d = n.getSemanticsData();
          return d.label == 'Close' && d.flagsCollection.isButton;
        }),
        isTrue,
      );
      handle.dispose();
    });
  });

  // ---------------------------------------------------------------- AC1
  group('T-0058-AC1 no overflow', () {
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final variant in McThemeVariant.values) {
        for (final scenario in _scenarios.entries) {
          testWidgets(
            'T-0058-AC1 ${scenario.key} with long German text at '
            '${scale}x ${variant.name} does not overflow',
            (tester) async {
              mcSetSurface(tester, 375, 667);
              await tester.pumpWidget(
                _scenarioApp(
                  scenario.key,
                  variant,
                  scale: scale,
                  long: true,
                ),
              );
              await scenario.value(tester, long: true);
              expect(tester.takeException(), isNull);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('T-0058-AC1 a dialog with a very tall body scrolls instead of '
        'overflowing', (tester) async {
      mcSetSurface(tester, 375, 500);
      await tester.pumpWidget(_plain(scale: 3));
      final answer = showMcDialog<void>(
        _ctx(tester),
        builder: (_) => McDialog(
          title: _german,
          body: Column(
            children: [for (var i = 0; i < 30; i++) Text('Line $i $_german')],
          ),
          actions: [
            McDialogAction(label: _german, onPressed: () {}),
            McDialogAction(
              label: _german,
              kind: McDialogActionKind.primary,
              onPressed: () {},
            ),
            McDialogAction(
              label: _german,
              kind: McDialogActionKind.destructive,
              onPressed: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(McDialog), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tapBarrier(tester);
      await answer;
    });

    testWidgets('T-0058-AC1 a sheet with a very tall body scrolls instead of '
        'overflowing', (tester) async {
      mcSetSurface(tester, 375, 500);
      await tester.pumpWidget(_plain(scale: 3));
      final answer = showMcSheet<void>(
        _ctx(tester),
        builder: (_) => McSheet(
          title: _german,
          dismissLabel: 'Close',
          child: Column(
            children: [for (var i = 0; i < 40; i++) Text('Line $i $_german')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(McSheet));
      expect(sheet.height, lessThanOrEqualTo(500));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await answer;
    });

    testWidgets('T-0058-AC1 a dialog and a sheet lay out under IntrinsicWidth '
        'and IntrinsicHeight (no LayoutBuilder, F-0043)', (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: IntrinsicHeight(
              child: IntrinsicWidth(
                child: Column(
                  children: [
                    McDialogBodyProbe.dialog(),
                    McDialogBodyProbe.choices(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('T-0058-AC1 the sheet body hosts anything', () {
    testWidgets('T-0058-AC1 McSheet keeps the bottom safe-area inset', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 667);
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(bottom: 34)),
            child: app!,
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: McSheet(
                title: 'Inset',
                dismissLabel: 'Close',
                child: Text('body', key: Key('test.body')),
              ),
            ),
          ),
        ),
      );
      final sheet = tester.getRect(find.byType(McSheet));
      final body = tester.getRect(find.byKey(const Key('test.body')));
      expect(sheet.bottom - body.bottom, greaterThanOrEqualTo(34 + 16));
    });
  });
}

/// Small stand-ins for the intrinsic probe: the real widgets without a route.
abstract final class McDialogBodyProbe {
  static Widget dialog() => McDialog(
    title: 'Probe',
    body: const Text('Body'),
    actions: [McDialogAction(label: 'OK', onPressed: () {})],
  );

  static Widget choices() => McChoiceList<String>(
    options: _options,
    selected: 'dark',
    onPicked: (_) {},
  );
}

// Scenarios: an overlay opened on the scenario app. `long` swaps in long
// German strings. The scenario app is `_plain` except for the menu.
typedef _Scenario = Future<void> Function(WidgetTester tester, {bool long});

final Map<String, _Scenario> _scenarios = {
  'dialog': (tester, {bool long = false}) async {
    await _confirm(
      tester,
      title: long ? _german : 'Delete comic?',
      message: long ? 'Löschen: $_german' : 'It will be removed.',
    );
  },
  'destructive dialog': (tester, {bool long = false}) async {
    await _confirm(
      tester,
      destructive: true,
      title: long ? _german : 'Delete comic?',
      message: long ? 'Löschen: $_german' : 'It will be removed.',
    );
  },
  'sheet': (tester, {bool long = false}) async {
    unawaited(
      showMcSheet<void>(
        _ctx(tester),
        dismissLabel: 'Close',
        builder: (_) => McSheet(
          title: long ? _german : 'Details',
          dismissLabel: 'Close',
          child: Text(long ? 'Beschreibung: $_german' : 'Some details.'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  },
  'choice sheet': (tester, {bool long = false}) async {
    await _openChoice(
      tester,
      selected: 'dark',
      options: [
        McChoiceOption(
          value: 'light',
          label: long ? _german : 'Light',
          icon: Icons.light_mode,
        ),
        McChoiceOption(
          value: 'dark',
          label: long ? 'Dunkel: $_german' : 'Dark',
          icon: Icons.dark_mode,
        ),
        const McChoiceOption(value: 'system', label: 'Follow the system'),
      ],
    );
  },
  'menu': (tester, {bool long = false}) async {
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
  },
  'toast': (tester, {bool long = false}) async {
    showMcToast(_ctx(tester), long ? 'Gespeichert: $_german' : 'Saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  },
  'toast with action': (tester, {bool long = false}) async {
    showMcToast(
      _ctx(tester),
      long ? 'Entfernt: $_german' : 'Comic removed',
      action: McToastAction(
        label: long ? 'Rückgängig machen' : 'Undo',
        onPressed: () {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  },
};

Widget _scenarioApp(
  String scenario,
  McThemeVariant variant, {
  double scale = 1,
  bool long = false,
}) => scenario == 'menu'
    ? _menuApp([], long: long, variant: variant, scale: scale)
    : _plain(variant: variant, scale: scale);
