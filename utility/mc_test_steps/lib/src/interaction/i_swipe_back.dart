import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I swipe back
///
/// The iOS edge-swipe gesture, not a back button: a drag from the left edge
/// across the screen (F-0018).
Future<void> iSwipeBack(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.dragFrom(
    Offset(2, size.height / 2),
    Offset(size.width * 0.8, 0),
  );
  await mcSettle(tester);
}
