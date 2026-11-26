import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:comics_details/src/presentation/bloc/comic_details_bloc.dart';
import 'package:comics_details/src/presentation/widget/favourite_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_media/mc_media.dart';

/// Key of the header's cover, for tests.
const comicCoverKey = ValueKey<String>('comics_details.cover');

/// Key of the header's title, for tests.
const comicTitleKey = ValueKey<String>('comics_details.title');

/// The first section: the cover (a tap opens it full size inside the flow),
/// the title, the issue number and the favourite toggle.
class ComicHeader extends StatelessWidget {
  const ComicHeader({required this.comic, super.key});

  /// The cover's width; its height follows the portrait aspect.
  static const double coverWidth = 120;

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final l10n = ComicsDetailsL10n.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.mcPalette;
    return Padding(
      padding: McInsets.screen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: coverWidth,
            child: Semantics(
              button: true,
              label: l10n.comicsDetailsCoverLabel(comic.title),
              child: GestureDetector(
                onTap: () => context.read<ComicDetailsBloc>().add(
                  const ComicDetailsEvent.openCover(),
                ),
                child: AspectRatio(
                  aspectRatio: 0.75,
                  child: ExcludeSemantics(
                    child: McImage(
                      key: comicCoverKey,
                      image: comic.cover,
                      variant: ImageVariant.portraitLarge,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const McGap.lg(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comic.title,
                  key: comicTitleKey,
                  style: text.titleLarge,
                ),
                const McGap.xs(),
                Text(
                  l10n.comicsDetailsIssue(comic.issueNumber),
                  style: text.bodyMedium?.copyWith(
                    color: palette.onSurfaceMuted,
                  ),
                ),
                const McGap.md(),
                const FavouriteToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
