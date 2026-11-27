import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One row of an [McMenuButton].
class McMenuItem<T> {
  const McMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// A disabled row is drawn muted, announced as disabled and ignores taps.
  final bool enabled;

  /// Draws the row in the error colour (Delete).
  final bool destructive;
}

/// An icon button that opens a menu of [items] and reports the picked
/// value through [onSelected]; dismissing the menu reports nothing.
///
/// [semanticLabel] names the button ("More actions"): the design system has
/// no localisation, so the feature passes it. It is the button's accessible
/// name and its hover tooltip. The menu opens on the **root** navigator by
/// default; `useRootNavigator: false` keeps it inside the nearest one. The
/// button and every row are at least 44 pt.
class McMenuButton<T> extends StatefulWidget {
  const McMenuButton({
    required this.items,
    required this.onSelected,
    required this.semanticLabel,
    this.icon = Icons.more_vert,
    this.useRootNavigator = true,
    super.key,
  }) : assert(items.length > 0, 'a menu needs at least one item');

  final List<McMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String semanticLabel;
  final IconData icon;
  final bool useRootNavigator;

  @override
  State<McMenuButton<T>> createState() => _McMenuButtonState<T>();
}

class _McMenuButtonState<T> extends State<McMenuButton<T>> {
  final _menuKey = GlobalKey<PopupMenuButtonState<T>>();

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final theme = Theme.of(context);
    // One semantics node carries the label, the button flag and the tap
    // action (as McIconButton does); the popup button's own nodes are
    // excluded so the name is read once.
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      onTap: () => _menuKey.currentState?.showButtonMenu(),
      excludeSemantics: true,
      child: Tooltip(
        message: widget.semanticLabel,
        child: Theme(
          data: theme.copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: p.surface,
              surfaceTintColor: Colors.transparent,
              elevation: McElevation.high,
              shape: RoundedRectangleBorder(
                borderRadius: McRadius.mdAll,
                side: BorderSide(color: p.outline),
              ),
            ),
          ),
          child: PopupMenuButton<T>(
            key: _menuKey,
            tooltip: '',
            icon: Icon(widget.icon, color: p.onSurface),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(mcMinTapTarget),
            ),
            useRootNavigator: widget.useRootNavigator,
            onSelected: widget.onSelected,
            itemBuilder: (_) => [
              for (final item in widget.items)
                PopupMenuItem<T>(
                  value: item.value,
                  enabled: item.enabled,
                  height: mcMinTapTarget,
                  child: _MenuRow(item: item),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final McMenuItem<dynamic> item;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final color = !item.enabled
        ? p.onSurfaceMuted
        : item.destructive
        ? p.error
        : p.onSurface;
    final iconSize = MediaQuery.textScalerOf(context).scale(20);
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: iconSize, color: color),
          const McGap.md(),
        ],
        Flexible(
          child: Text(
            item.label,
            style: McTypeScale.body.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
