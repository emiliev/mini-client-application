import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// `GET /v1/greeting` answers one greeting.
class GreetingDomain implements MockDomain {
  @override
  String get name => 'greeting';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router.get(
      '/v1/greeting',
      (request, context) => const MockResponse.ok({'text': 'Hello, Bazel'}),
    );
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() =>
    McFixtureSets.register('greeting.basic', GreetingDomain.new);
