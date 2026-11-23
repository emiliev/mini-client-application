import 'package:mc_fixtures_characters/src/data/universe.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const int defaultLimit = 20;
const int maxLimit = 100;

/// `GET /v1/characters`: pagination, `nameStartsWith` search and ordering.
///
/// Query: `offset` (default 0), `limit` (1 to 100, default 20),
/// `nameStartsWith` (case-insensitive), `orderBy` (`name`, `-name`,
/// `modified`, `-modified`; default `name`). Ties break on `id`, so the order
/// is total and stable.
MockHandler listCharacters(CharacterUniverse universe) => (request, context) {
  final (:query, :error) = _parse(request);
  if (query == null) {
    return error!;
  }

  var matches = universe.byName;
  if (query.prefix.isNotEmpty) {
    matches = [
      for (final c in matches)
        if (c.name.toLowerCase().startsWith(query.prefix)) c,
    ];
  }
  if (query.orderBy != 'name') {
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

typedef _Query = ({int offset, int limit, String orderBy, String prefix});

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
  final orderBy = request.query['orderBy'] ?? 'name';
  if (!_orders.containsKey(orderBy)) {
    return (
      query: null,
      error: _invalid('orderBy', 'must be one of ${_orders.keys.join(', ')}'),
    );
  }
  return (
    query: (
      offset: offset,
      limit: limit,
      orderBy: orderBy,
      prefix: (request.query['nameStartsWith'] ?? '').trim().toLowerCase(),
    ),
    error: null,
  );
}

final RegExp _digits = RegExp(r'^\d+$');

/// A non-negative decimal integer, or null. Unlike `int.tryParse` this
/// rejects `0x10`, `+5` and padded whitespace.
int? parseDigits(String raw) =>
    _digits.hasMatch(raw) ? int.tryParse(raw) : null;

/// `GET /v1/characters/:id`.
MockHandler characterDetail(CharacterUniverse universe) => (request, context) {
  final raw = context.params['id']!;
  final id = parseDigits(raw);
  final character = id == null ? null : universe.find(id);
  if (character == null) {
    return MockResponse.error(
      404,
      'character_not_found',
      'No character with id $raw',
      extra: {'id': raw},
    );
  }
  return MockResponse.ok(character.toDetailJson());
};

/// The `empty` scenario's list: validates like the real handler, then
/// answers a well-formed page with no results.
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

final Map<String, int Function(CharacterRecord, CharacterRecord)> _orders = {
  'name': (a, b) => _tie(a.name.compareTo(b.name), a, b),
  '-name': (a, b) => _tie(b.name.compareTo(a.name), a, b),
  'modified': (a, b) => _tie(a.modified.compareTo(b.modified), a, b),
  '-modified': (a, b) => _tie(b.modified.compareTo(a.modified), a, b),
};

int _tie(int primary, CharacterRecord a, CharacterRecord b) =>
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
