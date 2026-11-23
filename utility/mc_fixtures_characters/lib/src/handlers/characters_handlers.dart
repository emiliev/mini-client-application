import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import '../data/universe.dart';

const int defaultLimit = 20;
const int maxLimit = 100;

/// `GET /v1/characters`: pagination, `nameStartsWith` search and ordering.
///
/// Query: `offset` (default 0), `limit` (1 to 100, default 20),
/// `nameStartsWith` (case-insensitive), `orderBy` (`name`, `-name`,
/// `modified`, `-modified`; default `name`). Ties break on `id`, so the order
/// is total and stable.
MockHandler listCharacters(CharacterUniverse universe) => (request, context) {
  final offset = _intParam(request, 'offset', 0, min: 0);
  final limit = _intParam(
    request,
    'limit',
    defaultLimit,
    min: 1,
    max: maxLimit,
  );
  if (offset == null) return _invalid('offset', 'must be an integer >= 0');
  if (limit == null) {
    return _invalid('limit', 'must be an integer from 1 to $maxLimit');
  }

  final orderBy = request.query['orderBy'] ?? 'name';
  final compare = _orders[orderBy];
  if (compare == null) {
    return _invalid('orderBy', 'must be one of ${_orders.keys.join(', ')}');
  }

  final prefix = request.query['nameStartsWith']?.trim().toLowerCase();
  var matches = universe.byName;
  if (prefix != null && prefix.isNotEmpty) {
    matches = [
      for (final c in matches)
        if (c.name.toLowerCase().startsWith(prefix)) c,
    ];
  }
  if (orderBy != 'name') matches = [...matches]..sort(compare);

  final page = matches.skip(offset).take(limit).toList();
  return MockResponse.ok(
    pageEnvelope(
      offset: offset,
      limit: limit,
      total: matches.length,
      results: [for (final c in page) c.toSummaryJson()],
    ),
  );
};

/// `GET /v1/characters/:id`.
MockHandler characterDetail(CharacterUniverse universe) => (request, context) {
  final raw = context.params['id']!;
  final character = int.tryParse(raw) == null
      ? null
      : universe.find(int.parse(raw));
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

/// The `empty` scenario's list: a well-formed page with no results.
MockResponse emptyPage(MockRequest request, MockContext context) =>
    MockResponse.ok(
      pageEnvelope(
        offset: int.tryParse(request.query['offset'] ?? '') ?? 0,
        limit: int.tryParse(request.query['limit'] ?? '') ?? defaultLimit,
        total: 0,
        results: const [],
      ),
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
  if (raw == null) return fallback;
  final value = int.tryParse(raw);
  if (value == null || value < min || (max != null && value > max)) return null;
  return value;
}

MockResponse _invalid(String parameter, String rule) => MockResponse.error(
  400,
  'invalid_parameter',
  'Query parameter "$parameter" $rule',
  extra: {'parameter': parameter},
);
