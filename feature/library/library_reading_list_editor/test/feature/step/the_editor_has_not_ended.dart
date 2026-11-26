import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the editor has not ended
Future<void> theEditorHasNotEnded(WidgetTester tester) async =>
    expect(editorResults(), isEmpty, reason: 'the flow is still open');
