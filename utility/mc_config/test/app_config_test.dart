import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:test/test.dart';

const _json =
    '{"env":"dev","backend":{"seed":7,"latencyMs":250,"scenario":"happy"},'
    '"build":"3"}';

void main() {
  setUp(resetDIContainer);

  test('T-0020-AC1 parses typed values, latency as a Duration', () {
    final config = AppConfig.parse(_json);
    expect(config.env, 'dev');
    expect(config.backend.seed, 7);
    expect(config.backend.latency, const Duration(milliseconds: 250));
    expect(config.backend.scenario, 'happy');
    expect(config.build, '3');
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
}
