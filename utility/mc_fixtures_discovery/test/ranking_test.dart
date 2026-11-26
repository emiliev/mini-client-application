import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_media/mc_media.dart';

final ApiImage _image = ApiImage(path: 'mock-asset://characters/000');

SearchEntry _entry(
  int id,
  String title, {
  String type = 'character',
}) => SearchEntry(id: id, type: type, title: title, thumbnail: _image);

/// The ranked "type:id" labels of a search over [entries].
List<String> _ranked(String query, List<SearchEntry> entries) => [
  for (final m in SearchIndex(entries).search(query))
    '${m.entry.type}:${m.entry.id}',
];

List<String> _titles(String query, List<SearchEntry> entries) => [
  for (final m in SearchIndex(entries).search(query)) m.entry.title,
];

void main() {
  group('T-0043-AC2 folding', () {
    test('T-0043-AC2: case and diacritics are ignored', () {
      expect(foldText('Spïre WARDEN'), 'spire warden');
      expect(foldText('Crème Brûlée'), 'creme brulee');
      expect(foldText('Straße Œuvre Æther'), 'strasse oeuvre aether');
      // A decomposed accent (e + U+0301) folds like the composed one.
      expect(foldText('Café'), 'cafe');
    });

    test(
      'T-0043-AC2: comma-below, Vietnamese and Extended Additional fold',
      () {
        expect(foldText('Știința'), 'stiinta');
        expect(foldText('ŞŢ ȘȚ'), 'st st');
        expect(foldText('Việt Nam Ấn Độ'), 'viet nam an do');
        expect(foldText('Trường Đại học Ươ'), 'truong dai hoc uo');
        expect(foldText('ḍṛṭ Ẅẃ Ỹ'), 'drt ww y');
        expect(_ranked('stiinta', [_entry(1, 'Știința')]), ['character:1']);
      },
    );

    test('T-0043-AC2: an entry with an unknown type is refused', () {
      expect(
        () => _entry(1, 'Alpha', type: 'film'),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => _entry(1, 'Alpha', type: 'comic'), returnsNormally);
    });

    test('T-0043-AC2: whitespace runs collapse and the ends are trimmed', () {
      expect(foldText('  Spire \t  Warden  '), 'spire warden');
    });

    test('T-0043-AC2: a query with other case or marks finds the title', () {
      final entries = [_entry(1, 'Bát Cave'), _entry(2, 'Other')];
      expect(_ranked('BAT', entries), ['character:1']);
      expect(_ranked('báT cavé', entries), ['character:1']);
    });
  });

  group('T-0043-AC2 tiers', () {
    test('T-0043-AC2: matchTier classifies the four tiers', () {
      expect(matchTier('spire', 'spire'), MatchTier.exact);
      expect(matchTier('spire warden', 'spire'), MatchTier.prefix);
      expect(matchTier('warden of spire', 'spire'), MatchTier.wordPrefix);
      expect(matchTier('spirit', 'spire'), isNull);
      expect(matchTier('inspire', 'spire'), MatchTier.substring);
      expect(matchTier('spire', 'xyz'), isNull);
    });

    test('T-0043-AC2: the query may span words ("amber chr")', () {
      expect(matchTier('amber chronicles #1', 'amber chr'), MatchTier.prefix);
      expect(
        matchTier('the amber chronicles', 'amber chr'),
        MatchTier.wordPrefix,
      );
      expect(
        matchTier('the zamber chronicles', 'amber chr'),
        MatchTier.substring,
      );
    });

    test('T-0043-AC2: a non-BMP letter before the match is not a boundary', () {
      // U+1D49C (a letter) is two UTF-16 units; the low one alone looks like
      // a non-letter.
      expect(matchTier('\u{1D49C}alp', 'alp'), MatchTier.substring);
      expect(matchTier('\u{1D49C} alp', 'alp'), MatchTier.wordPrefix);
      expect(matchTier('x\u{1D49C}alp', 'alp'), MatchTier.substring);
    });

    test('T-0043-AC2: a word boundary is any non-letter, non-digit', () {
      expect(matchTier('x-alpha', 'alpha'), MatchTier.wordPrefix);
      expect(matchTier('x#alpha', 'alpha'), MatchTier.wordPrefix);
      expect(matchTier('xalpha', 'alpha'), MatchTier.substring);
      // The first occurrence is inside a word, a later one starts a word.
      expect(matchTier('kalpa alpha', 'alp'), MatchTier.wordPrefix);
    });

    test(
      'T-0043-AC2: exact ranks before prefix, though its title sorts later',
      () {
        // "Bat Cave" < "bat" as text; only the tier puts "bát" first.
        final entries = [_entry(1, 'Bat Cave'), _entry(2, 'Bát')];
        expect(_ranked('bat', entries), ['character:2', 'character:1']);
      },
    );

    test('T-0043-AC2: prefix ranks before word-prefix, though its title sorts later', () {
      // "Aardvark Alp" < "Alpha Zulu" as text.
      final entries = [_entry(1, 'Aardvark Alp'), _entry(2, 'Alpha Zulu')];
      expect(_ranked('alp', entries), ['character:2', 'character:1']);
    });

    test('T-0043-AC2: word-prefix ranks before substring, though its title sorts later', () {
      // "Kalpa" < "Zeta Alp" as text.
      final entries = [_entry(1, 'Kalpa'), _entry(2, 'Zeta Alp')];
      expect(_ranked('alp', entries), ['character:2', 'character:1']);
    });

    test('T-0043-AC2: all four tiers in one search come out in tier order', () {
      final entries = [
        _entry(1, 'Kalpa'),
        _entry(2, 'Zeta Alp'),
        _entry(3, 'Alpha Zulu'),
        _entry(4, 'ALP'),
        _entry(5, 'No match'),
      ];
      expect(_titles('alp', entries), [
        'ALP',
        'Alpha Zulu',
        'Zeta Alp',
        'Kalpa',
      ]);
      final tiers = [
        for (final m in SearchIndex(entries).search('alp')) m.tier,
      ];
      expect(tiers, MatchTier.values);
    });
  });

  group('T-0043-AC2 tie-breaks', () {
    test('T-0043-AC2: within a tier the title decides, not the id', () {
      // Ids run against the title order.
      final entries = [_entry(1, 'Alpha Zed'), _entry(2, 'Alpha Bee')];
      expect(_ranked('alp', entries), ['character:2', 'character:1']);
    });

    test('T-0043-AC2: the same title and type is ordered by id', () {
      // Fed in the reverse of the id order.
      final entries = [
        _entry(9, 'Alpha'),
        _entry(3, 'Alpha'),
        _entry(5, 'Alpha'),
      ];
      expect(_ranked('alp', entries), [
        'character:3',
        'character:5',
        'character:9',
      ]);
    });

    test('T-0043-AC2: the same title in two types puts characters first', () {
      // The comic has the lower id, so only the type rule puts it second.
      final entries = [
        _entry(1, 'Alpha', type: 'comic'),
        _entry(2, 'Alpha'),
      ];
      expect(_ranked('alp', entries), ['character:2', 'comic:1']);
    });

    test('T-0043-AC2: the title is compared as written (case counts)', () {
      // "ALPHA B" < "Alpha A" as text: upper case sorts first.
      final entries = [_entry(1, 'Alpha A'), _entry(2, 'ALPHA B')];
      expect(_ranked('alp', entries), ['character:2', 'character:1']);
    });

    test('T-0043-AC2: the order does not depend on the input order', () {
      final entries = [
        _entry(1, 'Kalpa'),
        _entry(2, 'Zeta Alp'),
        _entry(3, 'Alpha Zulu'),
        _entry(4, 'ALP'),
        _entry(5, 'Alpha', type: 'comic'),
        _entry(6, 'Alpha'),
      ];
      final expected = _ranked('alp', entries);
      expect(_ranked('alp', entries.reversed.toList()), expected);
    });
  });

  group('T-0043-AC2 index', () {
    test('T-0043-AC2: types filter keeps only the asked types', () {
      final index = SearchIndex([
        _entry(1, 'Alpha'),
        _entry(2, 'Alpha', type: 'comic'),
      ]);
      expect(
        [
          for (final m in index.search('alp', types: ['comic'])) m.entry.id,
        ],
        [2],
      );
      expect(index.search('alp', types: const []), isEmpty);
    });

    test('T-0043-AC2: the empty index matches nothing', () {
      expect(SearchIndex.empty.search('alp'), isEmpty);
    });

    test('T-0043-AC2: an entry serialises without a missing subtitle', () {
      expect(_entry(1, 'A').toJson().containsKey('subtitle'), isFalse);
      expect(
        SearchEntry(
          id: 1,
          type: 'comic',
          title: 'A',
          thumbnail: _image,
          subtitle: 's',
        ).toJson()['subtitle'],
        's',
      );
    });
  });
}
