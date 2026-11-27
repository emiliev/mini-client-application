import 'package:flutter_test/flutter_test.dart';

/// Usage: I press Search on the keyboard
///
/// The keyboard's action key (`TextInputAction.search`) on the focused text
/// field, then one frame with no fake time passing (zero-delay timers still
/// run): what it starts has started, a debounce has not fired.
Future<void> iPressSearchOnTheKeyboard(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump(Duration.zero);
}
