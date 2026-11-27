import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _german =
    'Donaudampfschifffahrtsgesellschaftskapitänsmützenabzeichen-Beschreibung';

const _choices = [
  McChoiceOption<String>(
    value: 'light',
    label: 'Light',
    icon: Icons.light_mode,
  ),
  McChoiceOption<String>(value: 'dark', label: 'Dark', icon: Icons.dark_mode),
  McChoiceOption<String>(value: 'system', label: 'Follow the system'),
];

/// Runs [open] once, after the first frame, with a context under the
/// `Scaffold` (so `ScaffoldMessenger` and the root navigator exist).
class _OpenAfterFirstFrame extends StatefulWidget {
  const _OpenAfterFirstFrame({required this.open, required this.child});

  final void Function(BuildContext context) open;
  final Widget child;

  @override
  State<_OpenAfterFirstFrame> createState() => _OpenAfterFirstFrameState();
}

class _OpenAfterFirstFrameState extends State<_OpenAfterFirstFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.open(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

T? _find<T extends State>(BuildContext context) {
  T? found;
  void visit(Element e) {
    if (found != null) {
      return;
    }
    if (e is StatefulElement && e.state is T) {
      found = e.state as T;
      return;
    }
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return found;
}

Widget _menu({bool long = false}) => _OpenAfterFirstFrame(
  open: (context) =>
      _find<PopupMenuButtonState<String>>(context)?.showButtonMenu(),
  child: Align(
    alignment: Alignment.topRight,
    child: McMenuButton<String>(
      semanticLabel: 'More actions',
      onSelected: (_) {},
      items: [
        McMenuItem(
          value: 'edit',
          label: long ? _german : 'Edit',
          icon: Icons.edit,
        ),
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
      ],
    ),
  ),
);

Widget _toast(String message, {McToastAction? action}) => _OpenAfterFirstFrame(
  open: (context) => showMcToast(context, message, action: action),
  child: const SizedBox.expand(),
);

Widget _dialog({
  String title = 'Delete comic?',
  String message = 'It will be removed from your library.',
  List<McDialogAction>? actions,
}) => McDialog(
  title: title,
  body: Text(message),
  actions:
      actions ??
      [
        McDialogAction(
          label: 'Delete',
          kind: McDialogActionKind.primary,
          onPressed: () {},
        ),
        McDialogAction(label: 'Keep', onPressed: () {}),
      ],
);

/// `mcGoldenMatrix` with real shadows: the test binding draws them as hard
/// black outlines, which is not what the app shows. The flag is restored
/// before the invariants are checked.
void _matrix({
  required String acId,
  required String component,
  required Widget Function(BuildContext context) builder,
  required double height,
  required double heightAtScale2,
  Duration settle = Duration.zero,
}) {
  for (final variant in McThemeVariant.values) {
    for (final scale in const [1.0, 2.0]) {
      final label = 'x${scale.toStringAsFixed(0)}';
      testWidgets('$acId $component golden ${variant.name} $label', (
        tester,
      ) async {
        await mcLoadFonts();
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        debugDisableShadows = false;
        try {
          mcSetSurface(tester, 375, scale > 1 ? heightAtScale2 : height);
          await tester.pumpWidget(
            mcGoldenApp(
              variant: variant,
              textScale: scale,
              child: Builder(builder: builder),
            ),
          );
          await tester.pump();
          if (settle > Duration.zero) {
            await tester.pump(settle);
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$component.${variant.name}.$label.png'),
          );
        } finally {
          debugDisableShadows = true;
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}

void main() {
  const ac = 'T-0058-AC1';
  const settle = Duration(milliseconds: 500);

  _matrix(
    acId: ac,
    component: 'dialog_default',
    height: 360,
    heightAtScale2: 640,
    builder: (_) => _dialog(),
  );
  _matrix(
    acId: ac,
    component: 'dialog_destructive',
    height: 360,
    heightAtScale2: 640,
    builder: (_) => _dialog(
      actions: [
        McDialogAction(
          label: 'Delete',
          kind: McDialogActionKind.destructive,
          onPressed: () {},
        ),
        McDialogAction(label: 'Keep', onPressed: () {}),
      ],
    ),
  );
  _matrix(
    acId: ac,
    component: 'dialog_three_actions_disabled',
    height: 460,
    heightAtScale2: 760,
    builder: (_) => _dialog(
      title: 'Leave the editor?',
      message: 'Your changes are not saved yet.',
      actions: [
        McDialogAction(
          label: 'Save and leave',
          kind: McDialogActionKind.primary,
          onPressed: () {},
        ),
        McDialogAction(
          label: 'Discard',
          kind: McDialogActionKind.destructive,
          onPressed: () {},
        ),
        const McDialogAction(label: 'Keep editing', onPressed: null),
      ],
    ),
  );
  _matrix(
    acId: ac,
    component: 'dialog_long',
    height: 560,
    heightAtScale2: 760,
    builder: (_) => _dialog(
      title: _german,
      message: 'Löschen: $_german',
      actions: [
        McDialogAction(
          label: 'Endgültig löschen: $_german',
          kind: McDialogActionKind.destructive,
          onPressed: () {},
        ),
        McDialogAction(label: 'Abbrechen und zurückkehren', onPressed: () {}),
      ],
    ),
  );

  _matrix(
    acId: ac,
    component: 'sheet_default',
    height: 300,
    heightAtScale2: 460,
    builder: (_) => const McSheet(
      title: 'Details',
      dismissLabel: 'Close',
      child: Text('Issue 1 of the main series, first printing.'),
    ),
  );
  _matrix(
    acId: ac,
    component: 'sheet_long',
    height: 460,
    heightAtScale2: 760,
    builder: (_) => const McSheet(
      title: _german,
      dismissLabel: 'Close',
      child: Text('Beschreibung: $_german'),
    ),
  );
  _matrix(
    acId: ac,
    component: 'choice_sheet_selected',
    height: 360,
    heightAtScale2: 600,
    builder: (_) => McSheet(
      title: 'Appearance',
      dismissLabel: 'Close',
      child: McChoiceList<String>(
        options: _choices,
        selected: 'dark',
        onPicked: (_) {},
      ),
    ),
  );
  _matrix(
    acId: ac,
    component: 'choice_sheet_none',
    height: 360,
    heightAtScale2: 600,
    builder: (_) => McSheet(
      title: 'Appearance',
      dismissLabel: 'Close',
      child: McChoiceList<String>(
        options: _choices,
        selected: null,
        onPicked: (_) {},
      ),
    ),
  );
  _matrix(
    acId: ac,
    component: 'choice_sheet_long',
    height: 560,
    heightAtScale2: 800,
    builder: (_) => McSheet(
      title: 'Darstellung auswählen',
      dismissLabel: 'Close',
      child: McChoiceList<String>(
        options: const [
          McChoiceOption(
            value: 'a',
            label: _german,
            icon: Icons.light_mode,
          ),
          McChoiceOption(value: 'b', label: 'Dunkel: $_german'),
          McChoiceOption(value: 'c', label: 'Dem System folgen'),
        ],
        selected: 'b',
        onPicked: (_) {},
      ),
    ),
  );

  _matrix(
    acId: ac,
    component: 'menu_open',
    height: 300,
    heightAtScale2: 460,
    settle: settle,
    builder: (_) => _menu(),
  );
  _matrix(
    acId: ac,
    component: 'menu_open_long',
    height: 400,
    heightAtScale2: 760,
    settle: settle,
    builder: (_) => _menu(long: true),
  );

  _matrix(
    acId: ac,
    component: 'tooltip_shown',
    height: 200,
    heightAtScale2: 300,
    settle: settle,
    builder: (_) => _OpenAfterFirstFrame(
      open: (context) => _find<TooltipState>(context)?.ensureTooltipVisible(),
      child: const Padding(
        padding: EdgeInsets.only(top: 80),
        child: McTooltip(
          message: 'Add to favourites',
          child: Icon(Icons.favorite_border, size: 44),
        ),
      ),
    ),
  );

  _matrix(
    acId: ac,
    component: 'toast',
    height: 240,
    heightAtScale2: 320,
    settle: settle,
    builder: (_) => _toast('Comic saved'),
  );
  _matrix(
    acId: ac,
    component: 'toast_action',
    height: 240,
    heightAtScale2: 360,
    settle: settle,
    builder: (_) => _toast(
      'Comic removed',
      action: McToastAction(label: 'Undo', onPressed: () {}),
    ),
  );
  _matrix(
    acId: ac,
    component: 'toast_long',
    height: 320,
    heightAtScale2: 560,
    settle: settle,
    builder: (_) => _toast(
      'Gespeichert: $_german',
      action: McToastAction(label: 'Rückgängig machen', onPressed: () {}),
    ),
  );
}
