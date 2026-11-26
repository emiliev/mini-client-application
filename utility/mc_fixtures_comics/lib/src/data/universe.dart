import 'package:mc_fixtures_comics/src/data/links.dart';
import 'package:mc_fixtures_comics/src/data/vocabulary.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// How many series the universe holds.
const int seriesCount = 120;

/// Issues per series; `comicCount` is `seriesCount * issuesPerSeries`.
const int issuesPerSeries = 20;

/// How many creators the pool holds.
const int creatorCount = 60;

const int comicIdBase = 500000;
const int seriesIdBase = 400000;
const int creatorIdBase = 300000;

/// `YYYY-MM-DD` of a UTC date.
String _day(DateTime d) => d.toIso8601String().substring(0, 10);

ApiImage _cover(int index) => ApiImage(
  path:
      'mock-asset://$coverImageSet/'
      '${(index % coverImageCount).toString().padLeft(3, '0')}',
  variant: ImageVariant.portraitLarge,
);

/// One credited creator on a comic.
final class CreatorCredit {
  const CreatorCredit({
    required this.id,
    required this.name,
    required this.role,
  });

  final int id;
  final String name;
  final String role;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'role': role};
}

/// A cover variant of a comic.
final class VariantRecord {
  const VariantRecord({required this.label, required this.cover});

  final String label;
  final ApiImage cover;

  Map<String, Object?> toJson() => {'label': label, 'cover': cover.toJson()};
}

/// One invented comic issue.
final class ComicRecord {
  const ComicRecord({
    required this.id,
    required this.title,
    required this.issueNumber,
    required this.seriesId,
    required this.seriesTitle,
    required this.description,
    required this.cover,
    required this.releaseDate,
    required this.priceCents,
    required this.pageCount,
    required this.creators,
    required this.characterIds,
    required this.variants,
  });

  final int id;
  final String title;
  final int issueNumber;
  final int seriesId;
  final String seriesTitle;
  final String description;
  final ApiImage cover;
  final DateTime releaseDate;
  final int priceCents;
  final int pageCount;
  final List<CreatorCredit> creators;

  /// Ids in `mc_fixtures_characters`, ascending.
  final List<int> characterIds;
  final List<VariantRecord> variants;

  /// The list shape: what a comic card needs.
  Map<String, Object?> toSummaryJson() => {
    'id': id,
    'title': title,
    'issueNumber': issueNumber,
    'seriesId': seriesId,
    'cover': cover.toJson(),
    'releaseDate': _day(releaseDate),
  };

  /// The detail shape: the summary plus everything else.
  Map<String, Object?> toDetailJson() => {
    ...toSummaryJson(),
    'description': description,
    'series': {'id': seriesId, 'title': seriesTitle},
    'creators': [for (final c in creators) c.toJson()],
    'characterIds': characterIds,
    'price': {'amountCents': priceCents, 'currency': 'USD'},
    'pageCount': pageCount,
    'variants': [for (final v in variants) v.toJson()],
  };
}

/// One invented series.
final class SeriesRecord {
  const SeriesRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.startYear,
    required this.endYear,
    required this.cover,
    required this.comicIds,
  });

  final int id;
  final String title;
  final String description;
  final int startYear;
  final int endYear;
  final ApiImage cover;

  /// The series' comics in issue order.
  final List<int> comicIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startYear': startYear,
    'endYear': endYear,
    'cover': cover.toJson(),
    'comicCount': comicIds.length,
    'comicIds': comicIds,
  };
}

/// The whole catalogue, a pure function of the seed.
///
/// Series titles and creator names depend only on their index (the same for
/// every seed); every other field is drawn from `seed -> 'comics' -> index`.
final class ComicUniverse {
  ComicUniverse(int seed) {
    final root = SplitMix64(seed).fork('comics');
    final creators = <CreatorCredit>[
      for (var c = 0; c < creatorCount; c++)
        CreatorCredit(
          id: creatorIdBase + c,
          name:
              '${creatorFirstNames[c % creatorFirstNames.length]} '
              '${creatorLastNames[(c ~/ creatorFirstNames.length) % creatorLastNames.length]}',
          role: '',
        ),
    ];
    final series = <SeriesRecord>[];
    final comics = <ComicRecord>[];
    for (var s = 0; s < seriesCount; s++) {
      final rng = root.fork('series').fork('$s');
      final title =
          '${seriesWords[s % seriesWords.length]} '
          '${seriesNouns[(s ~/ seriesWords.length) % seriesNouns.length]}';
      final startYear = 1985 + rng.nextInt(39);
      final premise = premises[rng.nextInt(premises.length)];
      final ids = <int>[];
      for (var k = 1; k <= issuesPerSeries; k++) {
        final index = s * issuesPerSeries + k - 1;
        final comic = _makeComic(
          root.fork('$index'),
          index: index,
          seriesIndex: s,
          seriesTitle: title,
          issue: k,
          startYear: startYear,
          creators: creators,
        );
        comics.add(comic);
        ids.add(comic.id);
      }
      series.add(
        SeriesRecord(
          id: seriesIdBase + s,
          title: title,
          description: 'The long-running story of $premise.',
          startYear: startYear,
          endYear: comics.last.releaseDate.year,
          cover: _cover(s),
          comicIds: ids,
        ),
      );
    }
    _init(comics, series);
  }

  /// A small synthetic catalogue for paging tests: one series, "Synthetic
  /// Series" (id [seriesIdBase]), holding `Issue 01` to `Issue <count>`
  /// (zero-padded so title order is issue order), ids from [comicIdBase],
  /// covers cycling through the bundled art, no creators, characters or
  /// variants. No randomness. With [count] 0 there is no series either.
  ComicUniverse.synthetic(int count) {
    final width = count.toString().length < 2 ? 2 : count.toString().length;
    final comics = [
      for (var i = 0; i < count; i++)
        ComicRecord(
          id: comicIdBase + i,
          title: 'Issue ${(i + 1).toString().padLeft(width, '0')}',
          issueNumber: i + 1,
          seriesId: seriesIdBase,
          seriesTitle: 'Synthetic Series',
          description: '',
          cover: _cover(i),
          releaseDate: DateTime.utc(2025).add(Duration(days: i)),
          priceCents: 399,
          pageCount: 32,
          creators: const [],
          characterIds: const [],
          variants: const [],
        ),
    ];
    _init(comics, [
      if (count > 0)
        SeriesRecord(
          id: seriesIdBase,
          title: 'Synthetic Series',
          description: '',
          startYear: 2025,
          endYear: comics.last.releaseDate.year,
          cover: _cover(0),
          comicIds: [for (final c in comics) c.id],
        ),
    ]);
  }

  void _init(List<ComicRecord> comics, List<SeriesRecord> series) {
    // Title order, with the id as tie-break: a stable total order.
    final sorted = [...comics]
      ..sort((a, b) {
        final byTitle = a.title.compareTo(b.title);
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });
    byTitle = List.unmodifiable(sorted);
    _comics = {for (final c in comics) c.id: c};
    _series = {for (final s in series) s.id: s};
    final byCharacter = <int, List<ComicRecord>>{};
    for (final c in byTitle) {
      for (final id in c.characterIds) {
        (byCharacter[id] ??= []).add(c);
      }
    }
    _byCharacter = byCharacter;
  }

  /// Every comic in title order.
  late final List<ComicRecord> byTitle;
  late final Map<int, ComicRecord> _comics;
  late final Map<int, SeriesRecord> _series;
  late final Map<int, List<ComicRecord>> _byCharacter;

  ComicRecord? findComic(int id) => _comics[id];

  SeriesRecord? findSeries(int id) => _series[id];

  /// The comics that feature [characterId], in title order.
  List<ComicRecord> comicsOfCharacter(int characterId) =>
      _byCharacter[characterId] ?? const [];

  /// Every series, by id.
  Iterable<SeriesRecord> get allSeries => _series.values;

  static ComicRecord _makeComic(
    SplitMix64 rng, {
    required int index,
    required int seriesIndex,
    required String seriesTitle,
    required int issue,
    required int startYear,
    required List<CreatorCredit> creators,
  }) {
    final roles = 2 + rng.nextInt(creatorRoles.length - 1);
    final credits = [
      for (var r = 0; r < roles; r++)
        () {
          final c = creators[rng.nextInt(creators.length)];
          return CreatorCredit(id: c.id, name: c.name, role: creatorRoles[r]);
        }(),
    ];
    final links = <int>{};
    final linkCount = 1 + rng.nextInt(6);
    while (links.length < linkCount) {
      links.add(characterIdBase + rng.nextInt(characterIdCount));
    }
    final labels = <String>{};
    final variantCount = rng.nextInt(3);
    while (labels.length < variantCount) {
      labels.add(variantLabels[rng.nextInt(variantLabels.length)]);
    }
    return ComicRecord(
      id: comicIdBase + index,
      title: '$seriesTitle #$issue',
      issueNumber: issue,
      seriesId: seriesIdBase + seriesIndex,
      seriesTitle: seriesTitle,
      description:
          'Issue $issue of $seriesTitle: '
          '${twists[rng.nextInt(twists.length)]} while '
          '${premises[rng.nextInt(premises.length)]} '
          'tries to keep a promise.',
      cover: _cover(rng.nextInt(coverImageCount)),
      // Monthly from January of the start year; DateTime.utc rolls months over.
      releaseDate: DateTime.utc(startYear, issue, 1 + rng.nextInt(28)),
      priceCents: 299 + 100 * rng.nextInt(4),
      pageCount: 24 + 8 * rng.nextInt(5),
      creators: credits,
      characterIds: (links.toList()..sort()),
      variants: [
        for (final label in labels)
          VariantRecord(
            label: label,
            cover: _cover(rng.nextInt(coverImageCount)),
          ),
      ],
    );
  }
}
