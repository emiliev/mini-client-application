import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/l10n/characters_list_l10n.dart';
import 'package:characters_list/src/presentation/bloc/character_preview_bloc.dart';
import 'package:characters_list/src/presentation/bloc/related_comics_bloc.dart';
import 'package:characters_list/src/presentation/widget/related_comics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_media/mc_media.dart';

/// Key of the preview's title (the character's name), for tests.
const characterPreviewTitleKey = ValueKey<String>(
  'characters_list.preview.title',
);

/// The in-flow preview of one character (a flow page, not a route): its art,
/// its name, "See full profile" and the comics it appears in, each of which
/// leaves the feature. The flow keys it by the character's id, so another
/// character gets a new page and blocs.
class CharacterPreviewPage extends StatelessWidget {
  const CharacterPreviewPage({required this.character, super.key});

  /// The flow state's selection.
  final Character character;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              context.di<CharacterPreviewBloc>(parameter: character),
        ),
        BlocProvider(
          create: (context) =>
              context.di<RelatedComicsBloc>(parameter: character),
        ),
      ],
      child: const _CharacterPreviewContent(),
    );
  }
}

class _CharacterPreviewContent extends StatelessWidget {
  const _CharacterPreviewContent();

  @override
  Widget build(BuildContext context) {
    final l10n = CharactersListL10n.of(context);
    return BlocBuilder<CharacterPreviewBloc, Character>(
      builder: (context, character) => Scaffold(
        appBar: McAppBar(
          title: character.name,
          titleKey: characterPreviewTitleKey,
        ),
        body: ListView(
          padding: McInsets.vertical,
          children: [
            Padding(
              padding: McInsets.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  McImage(
                    image: character.image,
                    variant: ImageVariant.portraitLarge,
                  ),
                  const McGap.lg(),
                  McButton(
                    label: l10n.charactersListPreviewSeeFullProfile,
                    expand: true,
                    onPressed: () => context.read<CharacterPreviewBloc>().add(
                      const CharacterPreviewEvent.seeFullProfile(),
                    ),
                  ),
                ],
              ),
            ),
            const McGap.lg(),
            // Full width: the section header and the rows bring their own
            // insets (DS lists are edge to edge).
            const RelatedComics(),
          ],
        ),
      ),
    );
  }
}
