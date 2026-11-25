import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/l10n/characters_list_l10n.dart';
import 'package:characters_list/src/presentation/bloc/character_preview_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_media/mc_media.dart';

/// Key of the preview's title (the character's name), for tests.
const characterPreviewTitleKey = ValueKey<String>(
  'characters_list.preview.title',
);

/// The in-flow preview of one character (a flow page, not a route): its art,
/// its name and "See full profile", which leaves the feature.
class CharacterPreviewPage extends StatelessWidget {
  const CharacterPreviewPage({required this.characterId, super.key});

  final CharacterId characterId;

  @override
  Widget build(BuildContext context) {
    // Read in build, not in `create` (F-0031 B; see CharactersListPage).
    final flow = FlowScope.of(context).container;
    return BlocProvider(
      create: (_) => flow<CharacterPreviewBloc>(parameter: characterId),
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
        appBar: AppBar(
          title: Text(character.name, key: characterPreviewTitleKey),
        ),
        body: ListView(
          padding: McInsets.screen,
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
    );
  }
}
