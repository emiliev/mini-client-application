import 'package:characters_search/src/domain/model/character.dart';
import 'package:characters_search/src/presentation/bloc/characters_search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_media/mc_media.dart';

/// A result's thumbnail, portrait (3:4).
const double characterResultArtWidth = 36;
const double characterResultArtHeight = 48;

/// The key of [character]'s row, for tests:
/// `characters_search.result.<id>`.
ValueKey<String> characterResultKey(Character character) =>
    ValueKey<String>('characters_search.result.${character.id.value}');

/// One result: its art and its name. A tap hands it over to the app
/// (through the bloc).
class CharacterResultTile extends StatelessWidget {
  const CharacterResultTile({required this.character, super.key});

  final Character character;

  @override
  Widget build(BuildContext context) => ListTile(
    key: characterResultKey(character),
    leading: McImage(
      image: character.image,
      variant: ImageVariant.portraitSmall,
      width: characterResultArtWidth,
      height: characterResultArtHeight,
    ),
    title: Text(character.name),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.read<CharactersSearchBloc>().add(
      CharactersSearchEvent.open(character.id),
    ),
  );
}
