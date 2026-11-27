import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// How many questions each template yields.
const int questionsPerTemplate = 24;

/// The category that draws from every category.
const String allCategory = 'all';

/// The real categories, in the order the categories route lists them.
const List<String> categoryIds = ['characters', 'comics', 'creators'];

/// The difficulties, easiest first.
const List<String> difficulties = ['easy', 'medium', 'hard'];

/// Seconds a player has per question, by difficulty.
const Map<String, int> timeLimitSecondsByDifficulty = {
  'easy': 20,
  'medium': 15,
  'hard': 10,
};

/// One answer option. [id] is `c1` to `c4`, fixed per question; the order the
/// options are shown in is the order of the list.
final class TriviaChoice {
  const TriviaChoice({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'text': text};
}

/// One multiple-choice question.
final class TriviaQuestion {
  const TriviaQuestion({
    required this.id,
    required this.template,
    required this.category,
    required this.difficulty,
    required this.prompt,
    required this.choices,
    required this.correctChoiceId,
    required this.facts,
    this.imageUrl,
  });

  /// `q-<template>-<nn>`, stable for a backend seed.
  final String id;

  /// The kind of question, e.g. `comic_year`.
  final String template;
  final String category;
  final String difficulty;
  final String prompt;
  final List<TriviaChoice> choices;
  final String correctChoiceId;

  /// What the question is about, as ids and values in the other fixture
  /// domains (never sent over the wire; the provider-contract tests check
  /// them against the characters and comics endpoints).
  final Map<String, Object> facts;

  /// A `mock-asset://` path of a bundled placeholder, or null.
  final String? imageUrl;

  int get timeLimitSeconds => timeLimitSecondsByDifficulty[difficulty]!;

  /// The text of the correct choice.
  String get correctText =>
      choices.firstWhere((c) => c.id == correctChoiceId).text;

  /// The same question with its choices in [order].
  TriviaQuestion withChoices(List<TriviaChoice> order) => TriviaQuestion(
    id: id,
    template: template,
    category: category,
    difficulty: difficulty,
    prompt: prompt,
    choices: order,
    correctChoiceId: correctChoiceId,
    facts: facts,
    imageUrl: imageUrl,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category,
    'difficulty': difficulty,
    'prompt': prompt,
    'choices': [for (final c in choices) c.toJson()],
    'correctChoiceId': correctChoiceId,
    'timeLimitSeconds': timeLimitSeconds,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

final Map<int, List<TriviaQuestion>> _banks = {};

/// Every question of the backend seed [seed], in a fixed order (by template,
/// then by number). A pure function of the seed, built once.
List<TriviaQuestion> triviaQuestionBank(int seed) =>
    _banks[seed] ??= List.unmodifiable(_Generator(seed).generate());

List<T> _shuffled<T>(Iterable<T> items, SplitMix64 rng) {
  final list = items.toList();
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final held = list[i];
    list[i] = list[j];
    list[j] = held;
  }
  return list;
}

/// Three distinct values from [pool], none in [exclude].
List<String> _sample(
  Iterable<String> pool,
  Set<String> exclude,
  SplitMix64 rng,
) {
  final seen = {...exclude};
  final out = <String>[];
  for (final item in _shuffled(pool, rng)) {
    if (seen.add(item)) {
      out.add(item);
      if (out.length == 3) {
        return out;
      }
    }
  }
  throw StateError('The pool is too small for three distractors');
}

/// Three years near [value] (within four), none equal to it.
List<String> _nearbyYears(int value, SplitMix64 rng) => _sample(
  [
    for (var d = -4; d <= 4; d++)
      if (d != 0 && value + d > 0) '${value + d}',
  ],
  {'$value'},
  rng,
);

String _money(int cents) =>
    '\$${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

typedef _Maker = TriviaQuestion? Function(
  int number,
  SplitMix64 rng,
  Object subject,
);

final class _Generator {
  _Generator(int seed)
    : _root = SplitMix64(seed).fork('trivia'),
      _comics = ComicUniverse(seed),
      _cast = CharacterUniverse(seed, defaultMockClock) {
    _teams = {for (final c in _cast.byName) c.team}.toList()..sort();
    _powers = {for (final c in _cast.byName) ...c.powers}.toList()..sort();
    _creatorNames = {
      for (final c in _comics.byTitle)
        for (final credit in c.creators) credit.name,
    }.toList()..sort();
  }

  final SplitMix64 _root;
  final ComicUniverse _comics;
  final CharacterUniverse _cast;
  late final List<String> _teams;
  late final List<String> _powers;
  late final List<String> _creatorNames;

  List<TriviaQuestion> generate() => [
    ..._template(
      'character_team',
      'characters',
      'easy',
      _cast.byName,
      _characterTeam,
    ),
    ..._template(
      'character_power',
      'characters',
      'medium',
      _cast.byName,
      _characterPower,
    ),
    ..._template(
      'character_debut_year',
      'characters',
      'medium',
      _cast.byName,
      _characterDebutYear,
    ),
    ..._template(
      'character_first_comic',
      'characters',
      'hard',
      _cast.byName,
      _characterFirstComic,
    ),
    ..._template(
      'character_debut',
      'characters',
      'hard',
      _cast.byName,
      _characterDebut,
    ),
    ..._template('comic_cast', 'comics', 'easy', _comics.byTitle, _comicCast),
    ..._template('comic_price', 'comics', 'easy', _comics.byTitle, _comicPrice),
    ..._template('comic_year', 'comics', 'medium', _comics.byTitle, _comicYear),
    ..._template(
      'series_start',
      'comics',
      'medium',
      _comics.allSeries,
      _seriesStart,
    ),
    ..._template('comic_pages', 'comics', 'hard', _comics.byTitle, _comicPages),
    ..._template('series_end', 'comics', 'hard', _comics.allSeries, _seriesEnd),
    ..._template(
      'creator_writer',
      'creators',
      'easy',
      _comics.byTitle,
      (n, r, s) => _creator(n, r, s as ComicRecord, 'writer', 'easy', 'wrote'),
    ),
    ..._template(
      'creator_penciller',
      'creators',
      'medium',
      _comics.byTitle,
      (n, r, s) =>
          _creator(n, r, s as ComicRecord, 'penciller', 'medium', 'penciled'),
    ),
    ..._template(
      'creator_inker',
      'creators',
      'hard',
      _comics.byTitle,
      (n, r, s) => _creator(n, r, s as ComicRecord, 'inker', 'hard', 'inked'),
    ),
  ];

  /// The first [questionsPerTemplate] subjects (in a seeded shuffle) that
  /// [make] accepts. `make` returns null for a subject it cannot use.
  List<TriviaQuestion> _template(
    String name,
    String category,
    String difficulty,
    Iterable<Object> subjects,
    _Maker make,
  ) {
    final base = _root.fork(name);
    final out = <TriviaQuestion>[];
    for (final subject in _shuffled(subjects, base.fork('subjects'))) {
      final number = out.length + 1;
      final question = make(number, base.fork('q$number'), subject);
      if (question != null) {
        out.add(
          TriviaQuestion(
            id: 'q-$name-${number.toString().padLeft(2, '0')}',
            template: name,
            category: category,
            difficulty: difficulty,
            prompt: question.prompt,
            choices: question.choices,
            correctChoiceId: question.correctChoiceId,
            facts: question.facts,
            imageUrl: question.imageUrl,
          ),
        );
        if (out.length == questionsPerTemplate) {
          break;
        }
      }
    }
    if (out.length < questionsPerTemplate) {
      throw StateError('Template $name yielded only ${out.length} questions');
    }
    return out;
  }

  /// A draft question: the template fills in the rest.
  TriviaQuestion _draft({
    required SplitMix64 rng,
    required String prompt,
    required String correct,
    required List<String> wrong,
    required Map<String, Object> facts,
    String? imageUrl,
  }) {
    final texts = _shuffled([correct, ...wrong], rng);
    assert(texts.toSet().length == 4, 'choices must be distinct');
    return TriviaQuestion(
      id: '',
      template: '',
      category: '',
      difficulty: '',
      prompt: prompt,
      choices: [
        for (var i = 0; i < texts.length; i++)
          TriviaChoice(id: 'c${i + 1}', text: texts[i]),
      ],
      correctChoiceId: 'c${texts.indexOf(correct) + 1}',
      facts: facts,
      imageUrl: imageUrl,
    );
  }

  TriviaQuestion _characterTeam(int n, SplitMix64 rng, Object s) {
    final c = s as CharacterRecord;
    return _draft(
      rng: rng,
      prompt: 'Which team does ${c.name} belong to?',
      correct: c.team,
      wrong: _sample(_teams, {c.team}, rng),
      facts: {'kind': 'character_team', 'characterId': c.id},
      imageUrl: c.thumbnail.path,
    );
  }

  TriviaQuestion _characterPower(int n, SplitMix64 rng, Object s) {
    final c = s as CharacterRecord;
    return _draft(
      rng: rng,
      prompt: 'Which of these is a power of ${c.name}?',
      correct: c.powers[rng.nextInt(c.powers.length)],
      wrong: _sample(_powers, {...c.powers}, rng),
      facts: {'kind': 'character_power', 'characterId': c.id},
      imageUrl: c.thumbnail.path,
    );
  }

  TriviaQuestion _characterDebutYear(int n, SplitMix64 rng, Object s) {
    final c = s as CharacterRecord;
    return _draft(
      rng: rng,
      prompt: 'In which year did ${c.name} first appear?',
      correct: '${c.firstAppearanceYear}',
      wrong: _nearbyYears(c.firstAppearanceYear, rng),
      facts: {'kind': 'character_debut_year', 'characterId': c.id},
      imageUrl: c.thumbnail.path,
    );
  }

  TriviaQuestion? _characterFirstComic(int n, SplitMix64 rng, Object s) {
    final c = s as CharacterRecord;
    final appearances = _comics.comicsOfCharacter(c.id);
    if (appearances.length < 2) {
      return null;
    }
    // The earliest release; a tie goes to the lower id (as the comics list
    // ordered by `releaseDate` does).
    final first = appearances.reduce(
      (a, b) => switch (a.releaseDate.compareTo(b.releaseDate)) {
        < 0 => a,
        > 0 => b,
        _ => a.id <= b.id ? a : b,
      },
    );
    return _draft(
      rng: rng,
      prompt: 'In which comic did ${c.name} first appear?',
      correct: first.title,
      wrong: _sample(
        [
          for (final other in _comics.byTitle)
            if (!other.characterIds.contains(c.id)) other.title,
        ],
        {first.title},
        rng,
      ),
      facts: {'kind': 'character_first_comic', 'characterId': c.id},
      imageUrl: c.thumbnail.path,
    );
  }

  final Set<int> _debutYearsUsed = {};

  TriviaQuestion? _characterDebut(int n, SplitMix64 rng, Object s) {
    final c = s as CharacterRecord;
    final year = c.firstAppearanceYear;
    // One question per year, so no two prompts are alike.
    if (!_debutYearsUsed.add(year)) {
      return null;
    }
    return _draft(
      rng: rng,
      prompt: 'Which of these characters first appeared in $year?',
      correct: c.name,
      wrong: _sample(
        [
          for (final other in _cast.byName)
            if (other.firstAppearanceYear != year) other.name,
        ],
        {c.name},
        rng,
      ),
      facts: {'kind': 'character_debut', 'characterId': c.id, 'year': year},
    );
  }

  TriviaQuestion _comicCast(int n, SplitMix64 rng, Object s) {
    final comic = s as ComicRecord;
    final member = comic.characters[rng.nextInt(comic.characters.length)];
    return _draft(
      rng: rng,
      prompt: 'Which character appears in ${comic.title}?',
      correct: member.name,
      wrong: _sample(
        [
          for (final c in _cast.byName)
            if (!comic.characterIds.contains(c.id)) c.name,
        ],
        {member.name},
        rng,
      ),
      facts: {'kind': 'comic_cast', 'comicId': comic.id},
      imageUrl: comic.cover.path,
    );
  }

  TriviaQuestion _comicPrice(int n, SplitMix64 rng, Object s) {
    final comic = s as ComicRecord;
    final correct = _money(comic.priceCents);
    return _draft(
      rng: rng,
      prompt: 'What was the cover price of ${comic.title}?',
      correct: correct,
      wrong: _sample(
        [for (var cents = 299; cents <= 599; cents += 100) _money(cents)],
        {correct},
        rng,
      ),
      facts: {'kind': 'comic_price', 'comicId': comic.id},
      imageUrl: comic.cover.path,
    );
  }

  TriviaQuestion _comicYear(int n, SplitMix64 rng, Object s) {
    final comic = s as ComicRecord;
    final year = comic.releaseDate.year;
    return _draft(
      rng: rng,
      prompt: 'In which year was ${comic.title} released?',
      correct: '$year',
      wrong: _nearbyYears(year, rng),
      facts: {'kind': 'comic_year', 'comicId': comic.id},
      imageUrl: comic.cover.path,
    );
  }

  TriviaQuestion _seriesStart(int n, SplitMix64 rng, Object s) {
    final series = s as SeriesRecord;
    return _draft(
      rng: rng,
      prompt: 'In which year did the series ${series.title} begin?',
      correct: '${series.startYear}',
      wrong: _nearbyYears(series.startYear, rng),
      facts: {'kind': 'series_start', 'seriesId': series.id},
      imageUrl: series.cover.path,
    );
  }

  TriviaQuestion _seriesEnd(int n, SplitMix64 rng, Object s) {
    final series = s as SeriesRecord;
    return _draft(
      rng: rng,
      prompt: 'In which year did the series ${series.title} end?',
      correct: '${series.endYear}',
      wrong: _nearbyYears(series.endYear, rng),
      facts: {'kind': 'series_end', 'seriesId': series.id},
      imageUrl: series.cover.path,
    );
  }

  TriviaQuestion _comicPages(int n, SplitMix64 rng, Object s) {
    final comic = s as ComicRecord;
    final correct = '${comic.pageCount}';
    return _draft(
      rng: rng,
      prompt: 'How many pages does ${comic.title} have?',
      correct: correct,
      wrong: _sample(
        [for (var pages = 24; pages <= 56; pages += 8) '$pages'],
        {correct},
        rng,
      ),
      facts: {'kind': 'comic_pages', 'comicId': comic.id},
      imageUrl: comic.cover.path,
    );
  }

  TriviaQuestion? _creator(
    int n,
    SplitMix64 rng,
    ComicRecord comic,
    String role,
    String difficulty,
    String verb,
  ) {
    final holders = {
      for (final c in comic.creators)
        if (c.role == role) c.name,
    };
    if (holders.length != 1) {
      return null;
    }
    return _draft(
      rng: rng,
      prompt: 'Who $verb ${comic.title}?',
      correct: holders.single,
      wrong: _sample(_creatorNames, holders, rng),
      facts: {'kind': 'creator_$role', 'comicId': comic.id, 'role': role},
      imageUrl: comic.cover.path,
    );
  }
}
