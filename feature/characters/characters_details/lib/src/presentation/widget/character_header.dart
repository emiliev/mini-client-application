import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/l10n/characters_details_l10n.dart';
import 'package:characters_details/src/presentation/widget/favourite_toggle.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_media/mc_media.dart';

/// Key of the header's portrait, for tests.
const characterPortraitKey = ValueKey<String>('characters_details.portrait');

/// Key of the header's name, for tests.
const characterNameKey = ValueKey<String>('characters_details.name');

/// Key of the header's aliases line, for tests.
const characterAliasesKey = ValueKey<String>('characters_details.aliases');

/// The first section: the portrait, the name, the aliases (when there are
/// any) and the favourite toggle.
class CharacterHeader extends StatelessWidget {
  const CharacterHeader({required this.character, super.key});

  /// The portrait's width; its height follows the portrait aspect.
  static const double portraitWidth = 120;

  final Character character;

  @override
  Widget build(BuildContext context) {
    final l10n = CharacterDetailsL10n.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.mcPalette;
    return Padding(
      padding: McInsets.screen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: portraitWidth,
            child: Semantics(
              image: true,
              label: l10n.characterDetailsPortraitLabel(character.name),
              child: AspectRatio(
                aspectRatio: 0.75,
                child: ExcludeSemantics(
                  child: McImage(
                    key: characterPortraitKey,
                    image: character.portrait,
                    variant: ImageVariant.portraitLarge,
                    width: double.infinity,
                    height: double.infinity,
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
                  character.name,
                  key: characterNameKey,
                  style: text.titleLarge,
                ),
                if (character.aliases.isNotEmpty) ...[
                  const McGap.xs(),
                  Text(
                    l10n.characterDetailsAliases(character.aliases.join(', ')),
                    key: characterAliasesKey,
                    style: text.bodyMedium?.copyWith(
                      color: palette.onSurfaceMuted,
                    ),
                  ),
                ],
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
