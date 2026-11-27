import 'package:characters_details/characters_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_details_env.dart';

/// Usage: the app was asked to open comic {'Brass Crossing #8'} {2} times
Future<void> theAppWasAskedToOpenComicTimes(
  WidgetTester tester,
  String title,
  int times,
) async {
  final navigator = charactersNavigator();
  verify(
    () => navigator.openComic(ComicId(comicTitled(title).id)),
  ).called(times);
  verifyNoMoreInteractions(navigator);
}
