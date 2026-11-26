import 'package:flutter/material.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One comic in step 3's reading order: its position, cover and title, a
/// drag handle, and up and down arrows (the accessible way to reorder).
class ReadingOrderRow extends StatelessWidget {
  const ReadingOrderRow({
    required this.index,
    required this.comic,
    required this.enabled,
    required this.onUp,
    required this.onDown,
    super.key,
  });

  final int index;
  final PickedComic comic;

  /// False while the list saves: no drag, no arrows.
  final bool enabled;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: McSpacing.lg,
          vertical: McSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}', style: text.labelLarge),
            ),
            McImage(image: comic.cover, width: 36, height: 54),
            const McGap.md(),
            Expanded(child: Text(comic.title, style: text.bodyLarge)),
            McIconButton(
              icon: Icons.arrow_upward,
              semanticLabel: l10n.readingListEditorMoveUp(comic.title),
              onPressed: onUp,
            ),
            McIconButton(
              icon: Icons.arrow_downward,
              semanticLabel: l10n.readingListEditorMoveDown(comic.title),
              onPressed: onDown,
            ),
            ReorderableDragStartListener(
              index: index,
              enabled: enabled,
              child: Padding(
                padding: const EdgeInsets.all(McSpacing.sm),
                child: Icon(Icons.drag_handle, color: p.onSurfaceMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
