import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/presentation/bloc/comic_details_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

/// Key of the cast section's row, for tests.
const comicCastKey = ValueKey<String>('comics_details.cast');

/// The characters section: one media card per cast member in a row that
/// scrolls sideways. A tap hands the character over to the app (through the
/// bloc).
class ComicCast extends StatelessWidget {
  const ComicCast({required this.cast, super.key});

  /// A card's width; its height follows the text scale.
  static const double cardWidth = 120;

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    final height = McMediaCard.heightFor(
      width: cardWidth,
      textScaler: MediaQuery.textScalerOf(context),
      hasSubtitle: false,
    );
    return SizedBox(
      height: height,
      child: ListView.separated(
        key: comicCastKey,
        scrollDirection: Axis.horizontal,
        padding: McInsets.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, _) => const McGap.md(),
        itemBuilder: (context, index) {
          final member = cast[index];
          return SizedBox(
            width: cardWidth,
            child: McMediaCard(
              title: member.name,
              image: member.image,
              onTap: () => context.read<ComicDetailsBloc>().add(
                ComicDetailsEvent.openCharacter(member.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
