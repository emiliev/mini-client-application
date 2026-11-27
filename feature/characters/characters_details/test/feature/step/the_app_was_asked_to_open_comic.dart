import 'package:characters_details/characters_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_details_env.dart';

/// Usage: the app was asked to open comic {'Brass Crossing #8'}
///
/// The navigator contract: `openComic` with the id of the comic titled
/// [title] (from the comics fixture), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenComic(
  WidgetTester tester,
  String title,
) async {
  final navigator = charactersNavigator();
  verify(() => navigator.openComic(ComicId(comicTitled(title).id))).called(1);
  verifyNoMoreInteractions(navigator);
}
