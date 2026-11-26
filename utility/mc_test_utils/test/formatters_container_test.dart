// Its own test target: intl's locale data is process-wide, and Flutter's
// GlobalMaterialLocalizations loads it too (for every locale it supports) as
// soon as a MaterialApp with those delegates builds. This test builds no
// widget, so only the container can have loaded it.
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

void main() {
  mcTestWidgets('T-0041-AC4 the test container loads the formatters, as the '
      "app's root list does", (tester) async {
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

    await McTestContainer.initialize(McTestSession.current);

    expect(formatDate(day, 'de'), '10. Jan. 1988');
  });
}
