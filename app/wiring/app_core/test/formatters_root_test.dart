// T-0041 (TL decision 1): the app's root list loads the formatters' locale
// data, so a feature formats German dates without loading anything itself.
// Its own test target: intl's locale data is process-wide.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

void main() {
  // The root list observes the app lifecycle for analytics sessions (T-0053),
  // which needs a binding, as the app has.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T-0041-AC4 the root list loads the German date symbols, after api '
      'auth and before the wirings', () async {
    final storage = Directory.systemTemp.createTempSync('formatters_root');
    addTearDown(() => storage.deleteSync(recursive: true));
    addTearDown(resetDIContainer);
    final day = DateTime.utc(1988, 1, 10);
    expect(
      () => formatDate(day, 'de'),
      throwsA(
        predicate((e) => '$e'.contains('Locale data has not been initialized')),
      ),
      reason: 'nothing has loaded the locale data yet',
    );

    final wiring = McDIInitializer((_, _) {});
    final list = rootInitializers(
      config: () async => _config,
      storageDirectory: storage,
      monitoringSinks: [InMemorySink()],
      wirings: [wiring],
    );
    final formatters = list.indexWhere((i) => i is FormattersDIInitializer);
    expect(
      formatters,
      greaterThan(list.indexWhere((i) => i is ApiAuthDIInitializer)),
    );
    expect(formatters, lessThan(list.indexOf(wiring)));

    await initializeDIContainer(list);

    expect(formatDate(day, 'de'), '10. Jan. 1988');
    expect(formatMoney(const Money(399, Currency.usd), 'de'), '3,99 \$');
  });
}
