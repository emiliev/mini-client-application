import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/l10n/characters_details_l10n.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

/// Key of the stats chart, for tests.
const characterStatsKey = ValueKey<String>('characters_details.stats');

/// The power stats as horizontal bars (`McBarChart`): one bar per stat, in
/// the order of [StatKind]. The chart's own semantics read each bar as
/// "Strength: 72", under a summary naming the character.
class CharacterStats extends StatelessWidget {
  const CharacterStats({required this.character, super.key});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final l10n = CharacterDetailsL10n.of(context);
    return Padding(
      padding: McInsets.horizontal,
      child: McBarChart(
        key: characterStatsKey,
        orientation: Axis.horizontal,
        semanticLabel: l10n.characterDetailsStatsLabel(character.name),
        emptyMessage: l10n.characterDetailsStatsEmpty,
        data: [
          for (final stat in character.stats)
            McBarDatum(
              label: statLabel(stat.kind, l10n),
              value: stat.value.toDouble(),
            ),
        ],
      ),
    );
  }
}

/// A stat as the user reads it.
String statLabel(StatKind kind, CharacterDetailsL10n l10n) => switch (kind) {
  StatKind.intelligence => l10n.characterDetailsStatIntelligence,
  StatKind.strength => l10n.characterDetailsStatStrength,
  StatKind.speed => l10n.characterDetailsStatSpeed,
  StatKind.durability => l10n.characterDetailsStatDurability,
  StatKind.energy => l10n.characterDetailsStatEnergy,
  StatKind.combat => l10n.characterDetailsStatCombat,
};
