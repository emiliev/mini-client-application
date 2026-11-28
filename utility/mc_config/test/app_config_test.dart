import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:test/test.dart';

const _json =
    '{"env":"dev","backend":{"seed":7,"latencyMs":250,"scenario":"happy"},'
    '"apiBaseUrl":"https://api.test","build":"3"}';

void main() {
  setUp(resetDIContainer);

  test('T-0020-AC1 parses typed values, latency as a Duration', () {
    final config = AppConfig.parse(_json);
    expect(config.env, 'dev');
    expect(config.backend.seed, 7);
    expect(config.backend.latency, const Duration(milliseconds: 250));
    expect(config.backend.scenario, 'happy');
    expect(config.build, '3');
    expect(config.apiBaseUrl, 'https://api.test/');
  });

  test('T-0070-AC1 version is optional: a non-empty string is kept, anything '
      'else (missing, empty, a number) is null', () {
    expect(
      AppConfig.parse(
        _json.replaceFirst('"build":"3"', '"build":"3","version":""'),
      ).version,
      isNull,
    );
    expect(AppConfig.parse(_json).version, isNull);
    expect(
      AppConfig.parse(
        _json.replaceFirst('"build":"3"', '"build":"3","version":"1.2.3"'),
      ).version,
      '1.2.3',
    );
    expect(
      AppConfig.parse(
        _json.replaceFirst('"build":"3"', '"build":"3","version":7'),
      ).version,
      isNull,
    );
  });

  test(
    'T-0020-AC1 initializer reads the source once and registers it',
    () async {
      var reads = 0;
      final container = await initializeDIContainer([
        ConfigDIInitializer(() async {
          reads++;
          return _json;
        }),
      ]);
      expect(container<AppConfig>().backend.seed, 7);
      expect(container<AppConfig>(), same(container<AppConfig>()));
      expect(reads, 1);
    },
  );

  group('T-0034-AC4 apiBaseUrl', () {
    String parseUrl(String url) => AppConfig.parse(
      '{"env":"dev","backend":{"seed":7,"latencyMs":0,"scenario":"happy"},'
      '"apiBaseUrl":"$url","build":"1"}',
    ).apiBaseUrl;

    test('T-0034-AC4 a value without a trailing slash is normalised', () {
      expect(parseUrl('https://api.test'), 'https://api.test/');
      expect(parseUrl('https://api.test/v2'), 'https://api.test/v2/');
    });

    test('T-0034-AC4 a value with a trailing slash is kept as it is', () {
      expect(parseUrl('https://api.test/'), 'https://api.test/');
    });

    test('T-0034-AC4 the constructor normalises too, with no assert', () {
      AppConfig build(String url) => AppConfig(
        env: 'dev',
        backend: const BackendConfig(
          seed: 1,
          latency: Duration.zero,
          scenario: 'happy',
        ),
        apiBaseUrl: url,
        build: '1',
      );

      expect(build('https://api.test').apiBaseUrl, 'https://api.test/');
      expect(build('https://api.test/').apiBaseUrl, 'https://api.test/');
    });

    test('T-0034-AC4 withTrailingSlash adds one slash and only one', () {
      expect(withTrailingSlash('https://a.test'), 'https://a.test/');
      expect(withTrailingSlash('https://a.test/'), 'https://a.test/');
      expect(withTrailingSlash('https://a.test/v2'), 'https://a.test/v2/');
      expect(withTrailingSlash(''), '/');
    });
  });

  group('T-0053-AC1 analytics default consent', () {
    String parse(String analytics) => AppConfig.parse(
      '{"env":"dev","backend":{"seed":7,"latencyMs":0,"scenario":"happy"},'
      '"apiBaseUrl":"https://api.test","build":"3"$analytics}',
    ).analytics.defaultConsent;

    test('a missing section or key means unknown', () {
      expect(parse(''), 'unknown');
      expect(parse(',"analytics":{}'), 'unknown');
    });

    test('the configured value is read', () {
      expect(parse(',"analytics":{"defaultConsent":"granted"}'), 'granted');
      expect(parse(',"analytics":{"defaultConsent":"denied"}'), 'denied');
    });
  });

  group('T-0053-AC1 a wrong-typed analytics config falls back to unknown', () {
    String parse(String analytics) => AppConfig.parse(
      '{"env":"dev","backend":{"seed":7,"latencyMs":0,"scenario":"happy"},'
      '"apiBaseUrl":"https://api.test","build":"3"$analytics}',
    ).analytics.defaultConsent;

    test('a number, a list, a bool, null or an object as the value', () {
      for (final value in ['1', '[]', 'true', 'null', '{"a":1}']) {
        expect(parse(',"analytics":{"defaultConsent":$value}'), 'unknown');
      }
    });

    test('a section that is not an object', () {
      for (final section in ['"granted"', '1', '[]', 'true', 'null']) {
        expect(parse(',"analytics":$section'), 'unknown');
      }
    });
  });
}
