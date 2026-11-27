import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
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

/// A sheet over a stand-in keyboard of 300 pt: the sheet is lifted by the
/// keyboard's inset and its body scrolls above it.
Widget _keyboardSheet(BuildContext context) => SizedBox.expand(
  child: Stack(
    children: [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 300,
        child: const ColoredBox(
          color: Color(0xFFB0B0B8),
          child: Center(child: Text('keyboard')),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
          child: McSheet(
            title: 'Rename list',
            dismissLabel: 'Close',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TextField(
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                McButton(label: 'Save', onPressed: () {}),
                McButton(
                  label: 'Cancel',
                  variant: McButtonVariant.tertiary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);

void main() {
  const ac = 'T-0058-AC1';
  const settle = Duration(milliseconds: 500);

  mcGoldenMatrix(
    realShadows: true,
    acId: ac,
    component: 'dialog_default',
    height: 360,
    heightAtScale2: 640,
    builder: (_) => _dialog(),
  );
  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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

  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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

  mcGoldenMatrix(
    realShadows: true,
    acId: ac,
    component: 'menu_open',
    height: 300,
    heightAtScale2: 460,
    settle: settle,
    builder: (_) => _menu(),
  );
  mcGoldenMatrix(
    realShadows: true,
    acId: ac,
    component: 'menu_open_long',
    height: 400,
    heightAtScale2: 760,
    settle: settle,
    builder: (_) => _menu(long: true),
  );

  mcGoldenMatrix(
    realShadows: true,
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

  mcGoldenMatrix(
    realShadows: true,
    acId: ac,
    component: 'toast',
    height: 240,
    heightAtScale2: 320,
    settle: settle,
    builder: (_) => _toast('Comic saved'),
  );
  mcGoldenMatrix(
    realShadows: true,
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
  mcGoldenMatrix(
    realShadows: true,
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

  mcGoldenMatrix(
    realShadows: true,
    acId: ac,
    component: 'sheet_keyboard',
    height: 560,
    heightAtScale2: 800,
    builder: _keyboardSheet,
  );
}
