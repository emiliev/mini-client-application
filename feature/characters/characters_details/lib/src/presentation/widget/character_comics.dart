import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/l10n/characters_details_l10n.dart';
import 'package:characters_details/src/presentation/bloc/character_details_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// Key of the comics row, for tests.
const characterComicsKey = ValueKey<String>('characters_details.comics');

/// Key of the text shown instead of the row when there are no comics.
const characterComicsEmptyKey = ValueKey<String>(
  'characters_details.comics.empty',
);

/// The comics section: one media card per comic in a row that scrolls
/// sideways. A tap hands the comic over to the app (through the bloc).
class CharacterComics extends StatelessWidget {
  const CharacterComics({required this.comics, super.key});

  /// A card's width; its height follows the text scale.
  static const double cardWidth = 120;

  final List<ComicSummary> comics;

  @override
  Widget build(BuildContext context) {
    if (comics.isEmpty) {
      return Padding(
        padding: McInsets.horizontal,
        child: Text(
          CharacterDetailsL10n.of(context).characterDetailsComicsEmpty,
          key: characterComicsEmptyKey,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.mcPalette.onSurfaceMuted,
          ),
        ),
      );
    }
    final height = McMediaCard.heightFor(
      width: cardWidth,
      textScaler: MediaQuery.textScalerOf(context),
      hasSubtitle: false,
    );
    return SizedBox(
      height: height,
      child: ListView.separated(
        key: characterComicsKey,
        scrollDirection: Axis.horizontal,
        padding: McInsets.horizontal,
        itemCount: comics.length,
        separatorBuilder: (_, _) => const McGap.md(),
        itemBuilder: (context, index) {
          final comic = comics[index];
          return SizedBox(
            width: cardWidth,
            child: McMediaCard(
              title: comic.title,
              image: comic.cover,
              onTap: () => context.read<CharacterDetailsBloc>().add(
                CharacterDetailsEvent.openComic(comic.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
