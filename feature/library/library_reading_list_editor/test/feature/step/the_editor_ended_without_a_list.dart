import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the editor ended without a list
///
/// The flow ended once, with no result (`onComplete(null)`).
Future<void> theEditorEndedWithoutAList(WidgetTester tester) async =>
    expect(editorResults(), [null], reason: 'the flow ended with no result');
