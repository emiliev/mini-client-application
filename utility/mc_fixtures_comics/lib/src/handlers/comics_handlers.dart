import 'package:mc_fixtures_comics/src/data/universe.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const int defaultLimit = 20;
const int maxLimit = 100;

/// `GET /v1/comics`: pagination, `titleStartsWith`, `characterId` and
/// ordering.
///
/// Query: `offset` (default 0), `limit` (1 to 100, default 20),
/// `titleStartsWith` (case-insensitive), `characterId` (comics featuring that
/// character; an unknown id matches nothing), `orderBy` (`title`, `-title`,
/// `releaseDate`, `-releaseDate`; default `title`). Ties break on `id`, so
/// the order is total and stable.
MockHandler listComics(ComicUniverse universe) => (request, context) {
  final (:query, :error) = _parse(request);
  if (query == null) {
    return error!;
  }

  var matches = query.characterId == null
      ? universe.byTitle
      : universe.comicsOfCharacter(query.characterId!);
  if (query.prefix.isNotEmpty) {
    matches = [
      for (final c in matches)
        if (c.title.toLowerCase().startsWith(query.prefix)) c,
    ];
  }
  if (query.orderBy != 'title') {
    matches = [...matches]..sort(_orders[query.orderBy]);
  }

  final page = matches.skip(query.offset).take(query.limit).toList();
  return MockResponse.ok(
    pageEnvelope(
      offset: query.offset,
      limit: query.limit,
      total: matches.length,
      results: [for (final c in page) c.toSummaryJson()],
    ),
  );
};

typedef _Query = ({
  int offset,
  int limit,
  String orderBy,
  String prefix,
  int? characterId,
});

/// Validates the list query once, for the normal and the `empty` handler.
({_Query? query, MockResponse? error}) _parse(MockRequest request) {
  final offset = _intParam(request, 'offset', 0, min: 0);
  final limit = _intParam(
    request,
    'limit',
    defaultLimit,
    min: 1,
    max: maxLimit,
  );
  if (offset == null) {
    return (query: null, error: _invalid('offset', 'must be an integer >= 0'));
  }
  if (limit == null) {
    return (
      query: null,
      error: _invalid('limit', 'must be an integer from 1 to $maxLimit'),
    );
  }
  final orderBy = request.query['orderBy'] ?? 'title';
  if (!_orders.containsKey(orderBy)) {
    return (
      query: null,
      error: _invalid('orderBy', 'must be one of ${_orders.keys.join(', ')}'),
    );
  }
  final rawCharacter = request.query['characterId'];
  final characterId = rawCharacter == null ? null : parseDigits(rawCharacter);
  if (rawCharacter != null && characterId == null) {
    return (
      query: null,
      error: _invalid('characterId', 'must be an integer id'),
    );
  }
  return (
    query: (
      offset: offset,
      limit: limit,
      orderBy: orderBy,
      prefix: (request.query['titleStartsWith'] ?? '').trim().toLowerCase(),
      characterId: characterId,
    ),
    error: null,
  );
}

final RegExp _digits = RegExp(r'^\d+$');

/// A non-negative decimal integer, or null. Unlike `int.tryParse` this
/// rejects `0x10`, `+5` and padded whitespace.
int? parseDigits(String raw) =>
    _digits.hasMatch(raw) ? int.tryParse(raw) : null;

/// `GET /v1/comics/:id`.
MockHandler comicDetail(ComicUniverse universe) => (request, context) {
  final raw = context.params['id']!;
  final id = parseDigits(raw);
  final comic = id == null ? null : universe.findComic(id);
  if (comic == null) {
    return _comicNotFound(raw);
  }
  return MockResponse.ok(comic.toDetailJson());
};

/// `GET /v1/series/:id`.
MockHandler seriesDetail(ComicUniverse universe) => (request, context) {
  final raw = context.params['id']!;
  final id = parseDigits(raw);
  final series = id == null ? null : universe.findSeries(id);
  if (series == null) {
    return _seriesNotFound(raw);
  }
  return MockResponse.ok(series.toJson());
};

MockResponse _comicNotFound(String raw) => MockResponse.error(
  404,
  'comic_not_found',
  'No comic with id $raw',
  extra: {'id': raw},
);

MockResponse _seriesNotFound(String raw) => MockResponse.error(
  404,
  'series_not_found',
  'No series with id $raw',
  extra: {'id': raw},
);

/// The `empty` set's list: validates like the real handler, then answers a
/// well-formed page with no results.
MockResponse emptyPage(MockRequest request, MockContext context) {
  final (:query, :error) = _parse(request);
  if (query == null) {
    return error!;
  }
  return MockResponse.ok(
    pageEnvelope(
      offset: query.offset,
      limit: query.limit,
      total: 0,
      results: const [],
    ),
  );
}

/// The `empty` set's detail: nothing exists, so every id is a 404.
MockResponse emptyComicDetail(MockRequest request, MockContext context) =>
    _comicNotFound(context.params['id']!);

/// The `empty` set's series detail: every id is a 404.
MockResponse emptySeriesDetail(MockRequest request, MockContext context) =>
    _seriesNotFound(context.params['id']!);

/// The `server_error` set: the exact body the `comics.server_error`
/// scenario's `FailureRule` produces, so both fail the same way.
MockResponse serverError(MockRequest request, MockContext context) =>
    MockResponse.error(
      500,
      'injected_failure',
      'Injected HTTP 500 for ${request.routeKey}',
    );

/// The paginated envelope every list endpoint shares.
Map<String, Object?> pageEnvelope({
  required int offset,
  required int limit,
  required int total,
  required List<Object?> results,
}) => {
  'offset': offset,
  'limit': limit,
  'total': total,
  'count': results.length,
  'results': results,
};

final Map<String, int Function(ComicRecord, ComicRecord)> _orders = {
  'title': compareByTitle,
  '-title': (a, b) => _tie(compareByTitle(b, a), a, b),
  'releaseDate': (a, b) => _tie(a.releaseDate.compareTo(b.releaseDate), a, b),
  '-releaseDate': (a, b) => _tie(b.releaseDate.compareTo(a.releaseDate), a, b),
};

int _tie(int primary, ComicRecord a, ComicRecord b) =>
    primary != 0 ? primary : a.id.compareTo(b.id);

/// The parsed int, [fallback] when absent, or null when invalid.
int? _intParam(
  MockRequest request,
  String name,
  int fallback, {
  required int min,
  int? max,
}) {
  final raw = request.query[name];
  if (raw == null) {
    return fallback;
  }
  final value = parseDigits(raw);
  if (value == null || value < min || (max != null && value > max)) {
    return null;
  }
  return value;
}

MockResponse _invalid(String parameter, String rule) => MockResponse.error(
  400,
  'invalid_parameter',
  'Query parameter "$parameter" $rule',
  extra: {'parameter': parameter},
);
