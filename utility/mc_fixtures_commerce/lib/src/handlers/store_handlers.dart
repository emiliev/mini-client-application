import 'package:mc_fixtures_commerce/src/data/catalogue.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const int defaultLimit = 20;
const int maxLimit = 100;

/// `GET /v1/store/banners`.
MockHandler banners({required bool empty}) =>
    (request, context) => MockResponse.ok({
      'banners': catalogueFor(context.seed, empty: empty).banners,
    });

/// `GET /v1/store/deals`.
MockHandler deals({required bool empty}) => (request, context) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  return MockResponse.ok({
    'deals': [for (final p in catalogue.deals) p.toDealJson(context.clock)],
  });
};

/// `GET /v1/store/categories`.
MockHandler categories({required bool empty}) => (request, context) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  return MockResponse.ok({
    'categories': [
      for (final c in catalogue.categories)
        {
          'id': c.id,
          'name': c.name,
          'count': catalogue.productsOf(c.id).length,
          'image': ApiImage(
            path:
                'mock-asset://characters/${c.imageIndex.toString().padLeft(3, '0')}',
            variant: ImageVariant.standard,
          ).toJson(),
        },
    ],
  });
};

/// `GET /v1/store/featured`.
MockHandler featured({required bool empty}) =>
    (request, context) => MockResponse.ok({
      'products': [
        for (final p in catalogueFor(context.seed, empty: empty).featured)
          p.toJson(),
      ],
    });

/// `GET /v1/store/categories/:id/products`: `offset` (default 0) and `limit`
/// (1 to 100, default 20), in comic title order.
MockHandler categoryProducts({required bool empty}) => (request, context) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  final id = context.params['id']!;
  if (catalogue.category(id) == null) {
    return MockResponse.error(
      404,
      'unknown_category',
      'No category "$id"',
      extra: {'categoryId': id},
    );
  }
  final offset = _intParam(request, 'offset', 0, min: 0);
  if (offset == null) {
    return _invalid('offset', 'must be a whole number, at least 0');
  }
  final limit = _intParam(
    request,
    'limit',
    defaultLimit,
    min: 1,
    max: maxLimit,
  );
  if (limit == null) {
    return _invalid('limit', 'must be a whole number from 1 to $maxLimit');
  }
  final matches = catalogue.productsOf(id);
  final page = matches.skip(offset).take(limit).toList();
  return MockResponse.ok({
    'offset': offset,
    'limit': limit,
    'total': matches.length,
    'count': page.length,
    'results': [for (final p in page) p.toJson()],
  });
};

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
  if (!RegExp(r'^\d{1,9}$').hasMatch(raw)) {
    return null;
  }
  final value = int.parse(raw);
  return value < min || (max != null && value > max) ? null : value;
}

MockResponse _invalid(String parameter, String rule) => MockResponse.error(
  400,
  'invalid_parameter',
  'Query parameter "$parameter" $rule',
  extra: {'parameter': parameter},
);

/// The `server_error` set and the per-section failures: the exact body the
/// scenarios' `FailureRule` produces, so both fail the same way.
MockResponse serverError(MockRequest request, MockContext context) =>
    MockResponse.error(
      500,
      'injected_failure',
      'Injected HTTP 500 for ${request.routeKey}',
    );
