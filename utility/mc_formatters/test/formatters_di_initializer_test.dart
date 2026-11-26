// Its own test target: intl's locale data is process-wide, so this process
// must not have loaded it before the first expectation.
import 'package:mc_di/mc_di.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:test/test.dart';

void main() {
  test(
    'T-0041-AC4 FormattersDIInitializer loads the German date symbols',
    () async {
      final day = DateTime.utc(1988, 1, 10);
      expect(
        () => formatDate(day, 'de'),
        throwsA(
          predicate(
            (e) => '$e'.contains('Locale data has not been initialized'),
          ),
        ),
        reason: 'nothing has loaded the locale data yet',
      );

      await initializeDIContainer([const FormattersDIInitializer()]);
      addTearDown(resetDIContainer);

      expect(formatDate(day, 'de'), '10. Jan. 1988');
      expect(formatDate(day, 'en'), 'Jan 10, 1988');
    },
  );
}
