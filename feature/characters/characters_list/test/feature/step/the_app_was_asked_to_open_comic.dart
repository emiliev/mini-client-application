import 'package:characters_list/characters_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_list_env.dart';

/// Usage: the app was asked to open comic {'Amber Requiem #8'}
///
/// The navigator contract: `openComic` with that comic's id (from the comics
/// fixture), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenComic(
  WidgetTester tester,
  String title,
) async {
  final navigator = charactersNavigator();
  final id = ComicId(comicTitled(title).id);
  verify(() => navigator.openComic(id)).called(1);
  verifyNoMoreInteractions(navigator);
}
