# T-0029-AC4: no analyzer in :bdd_test; DataTable from mc_test_steps

## `cquery 'deps(//spike/bdd_sample:bdd_test)' --notool_deps` (2952 targets)
```
analyzer / build / bdd_widget_test: none
```
## `cquery 'deps(//spike/bdd_sample:bdd_test)'` with tool deps (4457 targets)
- the test is in configuration `906ae0c`; the generator (a build tool) in `b1a3e4e`
- analyzer / build / bdd_widget_test targets are only in: `b1a3e4e `
  (the generator formats its output with dart_style, which depends on analyzer;
  none of it is compiled into or linked with the test)
## Data table: `greeting_table_test.dart` (generated)
```dart
4:import 'package:flutter_test/flutter_test.dart';
5:import 'package:mc_test_steps/mc_test_steps.dart' as bdd;
6:import 'package:mc_test_steps/mc_test_steps.dart';
7:import 'package:mc_test_utils/mc_test_utils.dart';
9:import './step/i_open_the_greeting.dart';
18:        const bdd.DataTable([
```

**PASS T-0029-AC4**
