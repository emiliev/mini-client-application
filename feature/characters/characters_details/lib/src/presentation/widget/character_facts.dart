import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/l10n/characters_details_l10n.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Key of the facts section, for tests.
const characterFactsKey = ValueKey<String>('characters_details.facts');

/// The facts section: origin, team (when there is one), the year of the first
/// appearance and the powers.
class CharacterFacts extends StatelessWidget {
  const CharacterFacts({required this.character, super.key});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final l10n = CharacterDetailsL10n.of(context);
    final facts = [
      if (character.origin.isNotEmpty)
        (l10n.characterDetailsFactOrigin, character.origin),
      if (character.team.isNotEmpty)
        (l10n.characterDetailsFactTeam, character.team),
      (
        l10n.characterDetailsFactFirstAppearance,
        '${character.firstAppearanceYear}',
      ),
      if (character.powers.isNotEmpty)
        (l10n.characterDetailsFactPowers, character.powers.join(', ')),
    ];
    return Padding(
      key: characterFactsKey,
      padding: McInsets.horizontal,
      child: Column(
        children: [
          for (final (label, value) in facts)
            _FactRow(label: label, value: value),
        ],
      ),
    );
  }
}

/// One fact: its label on the start side, its value on the end side, read
/// as one sentence by screen readers.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: McSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: context.mcPalette.onSurfaceMuted,
                ),
              ),
            ),
            const McGap.md(),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: text.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
