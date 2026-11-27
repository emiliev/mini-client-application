import 'dart:math' as math;

import 'package:mc_fixtures_characters/src/data/vocabulary.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// How many pictures the bundled `characters` art set holds
/// (`placeholderSets['characters']` in `mc_fixtures_media`). A constant, so
/// this package stays pure Dart and the comics fixture can read the cast
/// (T-0041); a provider-contract test checks it against the media package.
const int characterArtCount = 24;

/// How many characters the universe holds.
const int characterCount = 1500;

/// The power stats every character has, in the order the detail lists them
/// (the wire sorts keys; the order here only fixes how they are drawn).
const List<String> statNames = [
  'intelligence',
  'strength',
  'speed',
  'durability',
  'energy',
  'combat',
];

/// The first character id; ids are `idBase + generationIndex`.
const int idBase = 100000;

/// One invented character.
final class CharacterRecord {
  const CharacterRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.modified,
    required this.thumbnail,
    required this.powers,
    required this.team,
    required this.origin,
    required this.firstAppearanceYear,
    required this.comics,
    required this.series,
    required this.events,
    required this.aliases,
    required this.stats,
  });

  final int id;
  final String name;
  final String description;
  final DateTime modified;
  final ApiImage thumbnail;
  final List<String> powers;
  final String team;
  final String origin;
  final int firstAppearanceYear;
  final int comics;
  final int series;
  final int events;

  /// Other names, 0 to 2 of them, never the character's own name.
  final List<String> aliases;

  /// The six power stats by [statNames], each 1 to 100.
  final Map<String, int> stats;

  /// The list shape: what a character card needs.
  Map<String, Object?> toSummaryJson() => {
    'id': id,
    'name': name,
    'description': description,
    'modified': modified.toIso8601String(),
    'thumbnail': thumbnail.toJson(),
  };

  /// The detail shape: the summary plus everything else.
  Map<String, Object?> toDetailJson() => {
    ...toSummaryJson(),
    'powers': powers,
    'team': team,
    'origin': origin,
    'firstAppearanceYear': firstAppearanceYear,
    'appearances': {'comics': comics, 'series': series, 'events': events},
    'aliases': aliases,
    'stats': stats,
  };
}

/// The whole cast, a pure function of the seed.
///
/// A character's name depends only on its generation index (so the catalogue
/// is the same for every seed); every other field is drawn from
/// `seed -> 'characters' -> index`.
final class CharacterUniverse {
  CharacterUniverse(int seed, DateTime clock) {
    final root = SplitMix64(seed).fork('characters');
    final all = <CharacterRecord>[
      for (var i = 0; i < characterCount; i++) _make(root.fork('$i'), i, clock),
    ];
    // Name order, with the id as tie-break: a stable total order.
    all.sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
    byName = List.unmodifiable(all);
    _byId = {for (final c in all) c.id: c};
  }

  /// A small synthetic cast for paging tests: `Hero 01` to `Hero <count>`
  /// (zero-padded to at least two digits and to the width of [count], so
  /// name order is generation order), ids from [idBase], thumbnails cycling
  /// through the bundled `characters` art. No randomness: every field is a
  /// function of the index.
  CharacterUniverse.synthetic(int count, DateTime clock) {
    const images = characterArtCount;
    final width = math.max(2, '$count'.length);
    byName = List.unmodifiable([
      for (var i = 0; i < count; i++)
        CharacterRecord(
          id: idBase + i,
          name: 'Hero ${(i + 1).toString().padLeft(width, '0')}',
          description: '',
          modified: clock,
          thumbnail: ApiImage(
            path:
                'mock-asset://characters/'
                '${(i % images).toString().padLeft(3, '0')}',
          ),
          powers: const [],
          team: '',
          origin: '',
          firstAppearanceYear: 2000,
          comics: 0,
          series: 0,
          events: 0,
          aliases: const [],
          stats: {
            for (var k = 0; k < statNames.length; k++)
              statNames[k]: 1 + (i * 7 + k * 13) % 100,
          },
        ),
    ]);
    _byId = {for (final c in byName) c.id: c};
  }

  /// Every character in name order.
  late final List<CharacterRecord> byName;
  late final Map<int, CharacterRecord> _byId;

  CharacterRecord? find(int id) => _byId[id];

  static CharacterRecord _make(SplitMix64 rng, int index, DateTime clock) {
    final alias = aliasWords[index % aliasWords.length];
    final title = titleWords[(index ~/ aliasWords.length) % titleWords.length];
    final name = '$alias $title';
    final chosen = <String>{};
    while (chosen.length < 3) {
      chosen.add(powers[rng.nextInt(powers.length)]);
    }
    final origin = origins[rng.nextInt(origins.length)];
    final trait = traits[rng.nextInt(traits.length)];
    final year = 1962 + rng.nextInt(63);
    return CharacterRecord(
      id: idBase + index,
      name: name,
      description:
          '$name was $origin before a quiet accident turned '
          '${chosen.first.toLowerCase()} into a daily habit. '
          'Known to be $trait.',
      modified: clock.subtract(Duration(days: 1 + rng.nextInt(2000))),
      thumbnail: ApiImage(
        path:
            'mock-asset://characters/'
            '${rng.nextInt(characterArtCount).toString().padLeft(3, '0')}',
        variant: ImageVariant.portraitMedium,
      ),
      powers: (chosen.toList()..sort()),
      team: teams[rng.nextInt(teams.length)],
      origin: origin,
      firstAppearanceYear: year,
      comics: 1 + rng.nextInt(400),
      series: 1 + rng.nextInt(60),
      events: rng.nextInt(12),
      // Drawn after every field above, so adding them moved nothing that
      // was already served (T-0067).
      aliases: _aliases(rng, name),
      stats: {for (final stat in statNames) stat: 1 + rng.nextInt(100)},
    );
  }

  /// 0 to 2 distinct aliases, each `The <title word>`, never one the
  /// character's own name already ends with.
  static List<String> _aliases(SplitMix64 rng, String name) {
    final count = rng.nextInt(3);
    final chosen = <String>[];
    while (chosen.length < count) {
      final alias = 'The ${titleWords[rng.nextInt(titleWords.length)]}';
      if (!name.endsWith(alias.substring(4)) && !chosen.contains(alias)) {
        chosen.add(alias);
      }
    }
    return chosen;
  }
}
