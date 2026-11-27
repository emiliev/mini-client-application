import 'package:discovery_search/discovery_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/discovery_search_env.dart';

/// Usage: the app was asked to open comic {'Spindle Chronicles #1'}
///
/// The navigator contract: `openComic` with [title]'s id (from the fixture
/// index), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenComic(
  WidgetTester tester,
  String title,
) async {
  final navigator = searchNavigator();
  final id = ComicId(entryTitled('comic', title).id);
  verify(() => navigator.openComic(id)).called(1);
  verifyNoMoreInteractions(navigator);
}
