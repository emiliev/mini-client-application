import 'package:characters_details/characters_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_details_env.dart';

/// Usage: the app was asked to open comics {'Brass Crossing #8'} and {'Cinder Reckoning #2'}
///
/// `openComic` for each, once, and nothing else.
Future<void> theAppWasAskedToOpenComicsAnd(
  WidgetTester tester,
  String first,
  String second,
) async {
  final navigator = charactersNavigator();
  verify(() => navigator.openComic(ComicId(comicTitled(first).id))).called(1);
  verify(() => navigator.openComic(ComicId(comicTitled(second).id))).called(1);
  verifyNoMoreInteractions(navigator);
}
