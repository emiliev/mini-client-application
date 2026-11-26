import 'package:flutter/material.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// The key of a search result's row, for tests.
ValueKey<String> comicRowKey(PickedComic comic) =>
    ValueKey<String>('reading_list_editor.result.${comic.id.value}');

/// One search result: the cover, the title and a check mark when it is
/// picked. A tap toggles it; screen readers hear "Add …" or "Remove …" and
/// the selected state.
class ComicRow extends StatelessWidget {
  const ComicRow({
    required this.comic,
    required this.picked,
    required this.onTap,
    super.key,
  });

  final PickedComic comic;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final p = context.mcPalette;
    return Semantics(
      button: true,
      selected: picked,
      label: picked
          ? l10n.readingListEditorRemoveComic(comic.title)
          : l10n.readingListEditorAddComic(comic.title),
      excludeSemantics: true,
      child: InkWell(
        key: comicRowKey(comic),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: mcMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McSpacing.lg,
              vertical: McSpacing.xs,
            ),
            child: Row(
              children: [
                McImage(image: comic.cover, width: 36, height: 54),
                const McGap.md(),
                Expanded(
                  child: Text(
                    comic.title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const McGap.sm(),
                Icon(
                  picked ? Icons.check_circle : Icons.add_circle_outline,
                  color: picked ? p.primary : p.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
