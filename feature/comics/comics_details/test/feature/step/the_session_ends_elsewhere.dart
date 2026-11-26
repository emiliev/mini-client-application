import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the session ends elsewhere
///
/// The user signs out from another screen: the real `AuthApi.signOut`, inside
/// `runAsync` (the session clears a real file, F-0038).
Future<void> theSessionEndsElsewhere(WidgetTester tester) async {
  await tester.runAsync(() => diContainer<AuthApi>().signOut());
  await mcSettle(tester);
}
