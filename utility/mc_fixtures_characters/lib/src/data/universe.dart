import 'package:mc_fixtures_characters/src/data/vocabulary.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// How many characters the universe holds.
const int characterCount = 1500;

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
  /// (two digits, so name order is generation order), ids from [idBase],
  /// thumbnails cycling through the bundled `characters` art. No randomness:
  /// every field is a function of the index.
  CharacterUniverse.synthetic(int count, DateTime clock) {
    final images = placeholderSets['characters']!;
    byName = List.unmodifiable([
      for (var i = 0; i < count; i++)
        CharacterRecord(
          id: idBase + i,
          name: 'Hero ${(i + 1).toString().padLeft(2, '0')}',
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
            '${rng.nextInt(placeholderSets['characters']!).toString().padLeft(3, '0')}',
        variant: ImageVariant.portraitMedium,
      ),
      powers: (chosen.toList()..sort()),
      team: teams[rng.nextInt(teams.length)],
      origin: origin,
      firstAppearanceYear: year,
      comics: 1 + rng.nextInt(400),
      series: 1 + rng.nextInt(60),
      events: rng.nextInt(12),
    );
  }
}
