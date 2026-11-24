/// The shared Gherkin step library (plan 05 §3.2). Test-only.
///
/// Every step is one function in one file under `lib/src/<group>/`, named as
/// `bdd_widget_test` names it: the camelCase of the step text without its
/// parameters. The BDD generator resolves a step to this barrel when its file
/// name is in `:step_index`; a local step with the same name is a build error.
library;

export 'package:mc_test_steps/src/assertions/i_dont_see.dart';
export 'package:mc_test_steps/src/assertions/i_see.dart';
export 'package:mc_test_steps/src/assertions/i_see_the_texts.dart';
export 'package:mc_test_steps/src/backend/the_backend_serves.dart';
export 'package:mc_test_steps/src/data_table.dart';
export 'package:mc_test_steps/src/interaction/i_tap.dart';
