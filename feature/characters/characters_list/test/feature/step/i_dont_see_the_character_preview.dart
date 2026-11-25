import 'package:flutter_test/flutter_test.dart';

import '../util/characters_list_env.dart';

/// Usage: I don't see the character preview
///
/// The preview page left the flow (its `previewId` is cleared).
Future<void> iDontSeeTheCharacterPreview(WidgetTester tester) async => expect(
  find.byKey(characterPreviewTitleKey, skipOffstage: false),
  findsNothing,
);
