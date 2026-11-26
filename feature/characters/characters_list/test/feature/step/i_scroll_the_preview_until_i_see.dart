import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I scroll the preview until I see {'Amber Requiem #8'}
///
/// Real drags of the preview page until [text] is on screen.
Future<void> iScrollThePreviewUntilISee(
  WidgetTester tester,
  String text,
) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: previewScrollable().first,
  );
  await mcSettle(tester);
}
