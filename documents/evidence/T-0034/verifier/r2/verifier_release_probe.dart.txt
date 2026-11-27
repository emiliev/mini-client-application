// T-0034 Verifier probe (temporary): the base URL is normalised with asserts
// off, as in a release build. Run: fvm dart run --no-enable-asserts <this>.
import 'package:mc_api_client/src/api_dio.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

Future<void> main() async {
  var asserts = false;
  assert(asserts = true, 'detects whether asserts are on');
  print('asserts enabled: $asserts');

  final config = AppConfig(
    env: 'prod',
    backend: const BackendConfig(
      seed: 1,
      latency: Duration.zero,
      scenario: 'happy',
    ),
    apiBaseUrl: 'https://api.test',
    build: '1',
  );
  print('AppConfig(apiBaseUrl: "https://api.test").apiBaseUrl = '
      '${config.apiBaseUrl}');
  final parsed = AppConfig.parse(
    '{"env":"dev","backend":{"seed":1,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://api.test","build":"1"}',
  );
  print('AppConfig.parse(slashless).apiBaseUrl = ${parsed.apiBaseUrl}');

  final backend = MockBackend(domains: [const _Domain()]);
  final dio = createApiDio(
    adapter: backend.adapter,
    baseUrl: 'https://api.test',
    retryDelay: Duration.zero,
  );
  print('createApiDio(baseUrl: slashless).options.baseUrl = '
      '${dio.options.baseUrl}');
  await dio.get<Object?>('v1/characters');
  print('request path via createApiDio = '
      '${backend.recentTraffic.single.path}');

  final mockDio = backend.createDio(baseUrl: 'https://api.test');
  print('MockBackend.createDio(slashless).options.baseUrl = '
      '${mockDio.options.baseUrl}');
  await mockDio.get<Object?>('v1/characters');
  print('request path via MockBackend.createDio = '
      '${backend.recentTraffic.last.path}');
}

final class _Domain implements MockDomain {
  const _Domain();
  @override
  String get name => 'probe';
  @override
  Map<String, MockScenario> get scenarios => const {};
  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router.get('/v1/characters', (request, context) => const MockResponse.ok({'ok': true}));
  }
}
