import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:characters_details/src/domain/model/comic_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_media/mc_media.dart';

part 'character.freezed.dart';

/// A character as this page shows it. Domain model: no JSON, so a bare
/// `@freezed` (R30 is about models with JSON); the wire shape is
/// `CharacterDto`.
@freezed
abstract class Character with _$Character {
  const factory Character({
    required CharacterId id,
    required String name,

    /// Other names the character goes by; none for some.
    required List<String> aliases,

    /// The biography.
    required String bio,
    required ApiImage portrait,
    required String origin,

    /// The team the character belongs to; empty when none.
    required String team,
    required int firstAppearanceYear,
    required List<String> powers,

    /// Every [StatKind], in its declaration order, whatever the wire's key
    /// order.
    required List<CharacterStat> stats,
  }) = _Character;
}

/// One power stat: a [kind] and its [value], 1 to 100.
@freezed
abstract class CharacterStat with _$CharacterStat {
  const factory CharacterStat({
    required StatKind kind,
    required int value,
  }) = _CharacterStat;
}

/// A comic the character appears in: what a card shows.
@freezed
abstract class ComicSummary with _$ComicSummary {
  const factory ComicSummary({
    required ComicId id,
    required String title,
    required ApiImage cover,
  }) = _ComicSummary;
}

/// The power stats, in the order the chart draws them.
enum StatKind {
  intelligence('intelligence'),
  strength('strength'),
  speed('speed'),
  durability('durability'),
  energy('energy'),
  combat('combat');

  const StatKind(this.wireName);

  /// The key in the contract's `stats` object.
  final String wireName;
}
