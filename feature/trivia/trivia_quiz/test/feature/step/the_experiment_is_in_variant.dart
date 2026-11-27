import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the experiment {'trivia_hint'} is in variant {'hint'}
///
/// Puts the subject in a variant of an experiment, in the test container's
/// stub snapshot (`McTestFlags`), as a dev override does in the app. Set it
/// before the step that opens the flow.
Future<void> theExperimentIsInVariant(
  WidgetTester tester,
  String key,
  String variant,
) async => McTestSession.current.flags.forceVariant(key, variant);
