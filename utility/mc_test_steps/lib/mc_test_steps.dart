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
export 'package:mc_test_steps/src/assertions/nothing_overflows.dart';
export 'package:mc_test_steps/src/assertions/the_button_is_disabled.dart';
export 'package:mc_test_steps/src/assertions/the_field_reads.dart';
export 'package:mc_test_steps/src/backend/the_app_sends.dart';
export 'package:mc_test_steps/src/backend/the_backend_answered_with.dart';
export 'package:mc_test_steps/src/backend/the_backend_fails_with.dart';
export 'package:mc_test_steps/src/backend/the_backend_fails_with_once.dart';
export 'package:mc_test_steps/src/backend/the_backend_holds.dart';
export 'package:mc_test_steps/src/backend/the_backend_received.dart';
export 'package:mc_test_steps/src/backend/the_backend_received_requests_for.dart';
export 'package:mc_test_steps/src/backend/the_backend_received_with_the_bearer_of.dart';
export 'package:mc_test_steps/src/backend/the_backend_recovers.dart';
export 'package:mc_test_steps/src/backend/the_backend_releases.dart';
export 'package:mc_test_steps/src/backend/the_backend_serves.dart';
export 'package:mc_test_steps/src/backend_failure_names.dart';
export 'package:mc_test_steps/src/data_table.dart';
export 'package:mc_test_steps/src/environment/i_am_signed_in_as.dart';
export 'package:mc_test_steps/src/environment/milliseconds_pass.dart';
export 'package:mc_test_steps/src/environment/the_app_finishes_writing_to_storage.dart';
export 'package:mc_test_steps/src/environment/the_device_locale_is.dart';
export 'package:mc_test_steps/src/environment/the_pseudolocale_is_active.dart';
export 'package:mc_test_steps/src/interaction/i_pull_to_refresh.dart';
export 'package:mc_test_steps/src/interaction/i_swipe_back.dart';
export 'package:mc_test_steps/src/interaction/i_tap.dart';
export 'package:mc_test_steps/src/interaction/i_tap_the_icon_button.dart';
export 'package:mc_test_steps/src/interaction/i_tap_twice_in_quick_succession.dart';
export 'package:mc_test_steps/src/interaction/i_type.dart';
export 'package:mc_test_steps/src/interaction/i_type_one_character_at_a_time.dart';
