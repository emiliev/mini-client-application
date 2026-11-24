# T-0029-AC5: stock bdd_widget_test 3.0.5 fallback keeps AC IDs in test names

- overlay resolve: bdd_widget_test 3.0.5; drift from the committed overlay lock: none
## Stock-generated `test/feature/greeting_browse_test.dart`
```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'package:mc_test_steps/src/backend/the_backend_serves.dart';
import './step/i_open_the_greeting.dart';
import 'package:mc_test_steps/src/assertions/i_see.dart';
import 'package:mc_test_steps/src/interaction/i_tap.dart';
import 'package:mc_test_steps/src/assertions/i_dont_see.dart';

void main() {
  group('''Greeting''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theBackendServes(tester, 'greeting.basic');
    }

    mcTestWidgets('''The greeting is shown''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheGreeting(tester);
      await iSee(tester, 'Hello, Bazel');
    }, tags: ['T-0001-AC1', 'smoke']);
    mcTestWidgets('''Tapping the button says goodbye''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheGreeting(tester);
      await iTap(tester, 'Say goodbye');
      await iSee(tester, 'Goodbye');
      await iDontSee(tester, 'Hello, Bazel');
    }, tags: ['T-0029-AC1']);
  });
}
```
- the scenario's tags reach mcTestWidgets: `tags: ['T-0001-AC1', 'smoke']`
- step stubs the stock Builder wrote into the package: none
- `flutter test test/feature/fallback_all_test.dart`: exit 0
## Test names (flutter test JSON reporter; as JUnit in `fallback_junit.xml`)
```
success	greeting_browse Greeting The greeting is shown [T-0001-AC1]
success	greeting_browse Greeting Tapping the button says goodbye [T-0029-AC1]
```
- a passing test name ends with [T-0001-AC1]
- a passing test name ends with [T-0029-AC1]

**PASS T-0029-AC5**
