import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// A centred "nothing here" message.
class McEmptyView extends StatelessWidget {
  const McEmptyView({
    required this.message,
    this.title = 'Nothing here yet',
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: McInsets.screen,
        child: Semantics(
          container: true,
          label: '$title. $message',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: p.onSurfaceMuted),
                const McGap.md(),
                Text(
                  title,
                  style: text.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const McGap.xs(),
                Text(
                  message,
                  style: text.bodyMedium!.copyWith(color: p.onSurfaceMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
