import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend serves {'characters.paged_45'}
///
/// Switches on a fixture set registered with `McFixtureSets.register`. No
/// pump: the backend answers whatever the next step triggers.
Future<void> theBackendServes(WidgetTester tester, String set) async =>
    McTestSession.current.backend.useFixtureSet(set);
