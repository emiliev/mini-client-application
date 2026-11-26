import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the app sends {'GET /v1/me/favourites/comic/501500'}
///
/// Pumps frames until a request matching the route has reached the backend
/// harness (it may be held), and fails after 5 s of frames. With a hold
/// active, `mcSettle` pumps only two frames, so work that starts later (a
/// lazily created bloc's first read) may not have sent its request yet
/// (F-0040 fact 5); this step waits for exactly that.
Future<void> theAppSends(WidgetTester tester, String route) async {
  final backend = McTestSession.current.backend;
  for (var frame = 0; frame < 50; frame++) {
    if (backend.requests.any((r) => matchesRequest(r, route))) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the app did not send "$route"; received: ${backend.requests}');
}
