import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend runs the scenario {'store.deals_error'}
///
/// Switches on a named scenario of a served domain (its CONTRACT.md,
/// "Scenarios"), as the dev menu or `backend.scenario` in the app config
/// does: the domain's own bundle of failures and overrides. Serve the domain
/// first (`the backend serves {...}`), and run the scenario before any
/// `the backend fails ...` step, because switching scenarios resets the
/// engine's failure rules. `the backend recovers` ends it. An unknown name
/// fails, listing the known ones.
Future<void> theBackendRunsTheScenario(
  WidgetTester tester,
  String name,
) async => McTestSession.current.backend.backend.useScenario(name);
