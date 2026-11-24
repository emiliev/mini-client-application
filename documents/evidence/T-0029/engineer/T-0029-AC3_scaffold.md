# T-0029-AC3: scaffold writes step stubs

`tool/bazelw run //tool/bdd:scaffold -- --workspace <tmp> //spike/bdd_sample` (exit 0)
```
scaffold: wrote spike/bdd_sample/test/feature/step/i_wave_times.dart
scaffold: wrote spike/bdd_sample/test/feature/step/the_greeting_rows_are.dart
```
### test/feature/step/i_wave_times.dart
```dart
import 'package:flutter_test/flutter_test.dart';

/// Usage: I wave {2} times
Future<void> iWaveTimes(WidgetTester tester, num param1) async {
  throw UnimplementedError();
}
```
### test/feature/step/the_greeting_rows_are.dart
```dart
import 'package:mc_test_steps/mc_test_steps.dart' as bdd;
import 'package:flutter_test/flutter_test.dart';

/// Usage: the greeting rows are
Future<void> theGreetingRowsAre(
  WidgetTester tester,
  bdd.DataTable dataTable,
) async {
  throw UnimplementedError();
}
```
- exactly 3 step files: the existing one and the 2 stubs (no stub for shared steps)
- the existing step is unchanged
- a second run writes nothing

**PASS T-0029-AC3**
