import 'package:flutter_test/flutter_test.dart';

import '../util/auth_signin_env.dart';

/// Usage: the sign-in completed with {'signedIn'}
///
/// The flow ended once, with that result (`onComplete`): what the wiring
/// hands back to the caller. `'signedIn'` or `'cancelled'`.
Future<void> theSigninCompletedWith(WidgetTester tester, String name) async =>
    expect(
      [for (final r in signInResults()) r.name],
      [name],
      reason: 'the flow result',
    );
