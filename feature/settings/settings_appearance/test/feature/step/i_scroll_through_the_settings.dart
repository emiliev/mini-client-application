import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: I scroll through the settings
///
/// Scrolls the settings to their end and back, so every row is built and
/// laid out (a lazy list builds only what is near the screen).
Future<void> iScrollThroughTheSettings(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byKey(appearanceBodyKey),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  while (position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      (position.pixels + 200).clamp(0, position.maxScrollExtent).toDouble(),
    );
    await tester.pump();
  }
  position.jumpTo(0);
  await tester.pump();
}
