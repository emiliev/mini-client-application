import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/backend_failure_names.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend fails {'PUT /v1/me/favourites/comic/501500'} with {'unauthorized'} once
///
/// The next matching request fails, later ones get the normal answer (a
/// client retry or a replay after a token refresh included).
Future<void> theBackendFailsWithOnce(
  WidgetTester tester,
  String route,
  String kind,
) async => McTestSession.current.backend.fail(
  route,
  backendFailureNamed(kind),
  times: 1,
);
