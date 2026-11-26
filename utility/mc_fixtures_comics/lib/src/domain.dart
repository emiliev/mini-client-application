import 'package:mc_fixtures_comics/src/data/universe.dart';
import 'package:mc_fixtures_comics/src/handlers/comics_handlers.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The routes of the comics domain, as `"METHOD /pattern"`. Documented in
/// `CONTRACT.md`; the same routes are listed in `fixtures/routes.json`, and a
/// test keeps the three in step.
const List<String> comicsRouteManifest = [
  'GET /v1/comics',
  'GET /v1/comics/:id',
  'GET /v1/series/:id',
];

void _registerRoutes(MockRouter router, ComicUniverse universe) {
  router
    ..get('/v1/comics', listComics(universe))
    ..get('/v1/comics/:id', comicDetail(universe))
    ..get('/v1/series/:id', seriesDetail(universe));
}

/// The comics domain: `GET /v1/comics`, `GET /v1/comics/:id` and
/// `GET /v1/series/:id`.
final class ComicsMockDomain implements MockDomain {
  const ComicsMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = comicsRouteManifest;

  @override
  String get name => 'comics';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _registerRoutes(router, ComicUniverse(environment.seed));

  @override
  Map<String, MockScenario> get scenarios => {
    'comics.empty': const MockScenario(
      'comics.empty',
      overrides: {
        'GET /v1/comics': emptyPage,
        'GET /v1/comics/:id': emptyComicDetail,
        'GET /v1/series/:id': emptySeriesDetail,
      },
    ),
    'comics.server_error': const MockScenario(
      'comics.server_error',
      rules: [
        FailureRule('GET', '/v1/comics', FailureKind.http(500)),
        FailureRule('GET', '/v1/comics/:id', FailureKind.http(500)),
        FailureRule('GET', '/v1/series/:id', FailureKind.http(500)),
      ],
    ),
  };
}

/// The comics routes over a synthetic catalogue of [count] comics in one
/// series (`Issue 01` ...), with the same paging, validation and envelope as
/// [ComicsMockDomain]. It has no scenarios, so it never clashes with that
/// domain's names. With [count] 0 every detail is a 404.
final class SyntheticComicsDomain implements MockDomain {
  const SyntheticComicsDomain(this.count);

  final int count;

  @override
  String get name => 'comics';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _registerRoutes(router, ComicUniverse.synthetic(count));

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The comics routes, each answering `500`. For tests of the failure state
/// without a scenario switch. It has no scenarios.
final class FailingComicsDomain implements MockDomain {
  const FailingComicsDomain();

  @override
  String get name => 'comics';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router
      ..get('/v1/comics', serverError)
      ..get('/v1/comics/:id', serverError)
      ..get('/v1/series/:id', serverError);
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}
