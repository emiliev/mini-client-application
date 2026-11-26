import 'package:mc_fixtures_discovery/src/search/index.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const int defaultLimit = 20;
const int maxLimit = 100;
const int minQueryLength = 2;
const int suggestionCount = 5;

typedef _Params = ({String query, List<String> types, int limit});

/// `GET /v1/search`: `q` (trimmed, at least 2 characters), `types`
/// (comma-separated, default every type) and `limit` per group (1 to 100,
/// default 20). One group per requested type, in the fixed order character,
/// comic, each ranked by tier, title and id.
MockHandler search(SearchIndex index) => (request, context) {
  final (:params, :error) = _parse(request);
  if (params == null) {
    return error!;
  }
  final matches = index.search(params.query, types: params.types);
  return MockResponse.ok({
    'query': params.query,
    'groups': [
      for (final type in searchTypes)
        if (params.types.contains(type))
          _group(type, [
            for (final m in matches)
              if (m.entry.type == type) m.entry,
          ], params.limit),
    ],
  });
};

Map<String, Object?> _group(String type, List<SearchEntry> all, int limit) => {
  'type': type,
  'total': all.length,
  'results': [for (final e in all.take(limit)) e.toJson()],
};

/// `GET /v1/search/suggestions`: `q` (as above); the best 5 distinct titles
/// across the types, ranked like a search.
MockHandler suggestions(SearchIndex index) => (request, context) {
  final (:value, :error) = _query(request);
  if (value == null) {
    return error!;
  }
  final titles = <String>[];
  for (final m in index.search(value)) {
    if (!titles.contains(m.entry.title)) {
      titles.add(m.entry.title);
      if (titles.length == suggestionCount) {
        break;
      }
    }
  }
  return MockResponse.ok({'query': value, 'suggestions': titles});
};

({_Params? params, MockResponse? error}) _parse(MockRequest request) {
  final (:value, :error) = _query(request);
  if (value == null) {
    return (params: null, error: error);
  }
  final types = _types(request);
  if (types == null) {
    return (
      params: null,
      error: _invalid('types', 'must list only ${searchTypes.join(', ')}'),
    );
  }
  final limit = _limit(request);
  if (limit == null) {
    return (
      params: null,
      error: _invalid('limit', 'must be an integer from 1 to $maxLimit'),
    );
  }
  return (params: (query: value, types: types, limit: limit), error: null);
}

({String? value, MockResponse? error}) _query(MockRequest request) {
  final q = (request.query['q'] ?? '').trim();
  if (q.runes.length < minQueryLength) {
    return (
      value: null,
      error: MockResponse.error(
        400,
        'query_too_short',
        'Query parameter "q" needs at least $minQueryLength characters',
        extra: {'parameter': 'q', 'minLength': minQueryLength},
      ),
    );
  }
  return (value: q, error: null);
}

/// The requested types, or null when one is unknown or the list is empty. An
/// absent `types` means all of them.
List<String>? _types(MockRequest request) {
  final raw = request.query['types'];
  if (raw == null) {
    return searchTypes;
  }
  final asked = [for (final t in raw.split(',')) t.trim()];
  if (asked.any((t) => !searchTypes.contains(t))) {
    return null;
  }
  return asked;
}

final RegExp _digits = RegExp(r'^\d+$');

int? _limit(MockRequest request) {
  final raw = request.query['limit'];
  if (raw == null) {
    return defaultLimit;
  }
  final value = _digits.hasMatch(raw) ? int.tryParse(raw) : null;
  return value == null || value < 1 || value > maxLimit ? null : value;
}

MockResponse _invalid(String parameter, String rule) => MockResponse.error(
  400,
  'invalid_parameter',
  'Query parameter "$parameter" $rule',
  extra: {'parameter': parameter},
);

/// The `server_error` set: the exact body the `discovery.server_error`
/// scenario's `FailureRule` produces, so both fail the same way.
MockResponse serverError(MockRequest request, MockContext context) =>
    MockResponse.error(
      500,
      'injected_failure',
      'Injected HTTP 500 for ${request.routeKey}',
    );
