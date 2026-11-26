import 'package:comics_details/comics_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/comics_details_env.dart';

/// Usage: the app was asked to open creator {'Esme Garrow'} of comic {501500}
///
/// The navigator contract: `openCreator` with that credit's id (from the
/// comics fixture), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenCreatorOfComic(
  WidgetTester tester,
  String name,
  int comic,
) async {
  final navigator = comicsNavigator();
  final credit = comicRecord(comic).creators.firstWhere((c) => c.name == name);
  verify(() => navigator.openCreator(CreatorId(credit.id))).called(1);
  verifyNoMoreInteractions(navigator);
}
