import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/presentation/bloc/characters_list_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';

/// One character in the grid: its name and bundled art on a media card.
/// A tap dispatches an event; only the bloc changes the flow (plan 01 §4.1).
class CharacterTile extends StatelessWidget {
  const CharacterTile({required this.character, super.key});

  final Character character;

  @override
  Widget build(BuildContext context) => McMediaCard(
    title: character.name,
    image: character.image,
    onTap: () => context.read<CharactersListBloc>().add(
      CharactersListEvent.preview(character),
    ),
  );
}
