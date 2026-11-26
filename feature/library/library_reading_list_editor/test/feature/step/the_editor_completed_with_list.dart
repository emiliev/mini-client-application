import 'package:flutter_test/flutter_test.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the editor completed with list {'l-5'}
///
/// The flow ended once, with that list's id as its result (`onComplete`):
/// what the wiring hands back to the caller.
Future<void> theEditorCompletedWithList(WidgetTester tester, String id) async =>
    expect(editorResults(), [ReadingListId(id)], reason: 'the flow result');
