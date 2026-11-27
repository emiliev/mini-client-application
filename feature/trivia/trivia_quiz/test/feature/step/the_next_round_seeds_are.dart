import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the next round seeds are {'42, 7'}
///
/// The seeds the next rounds started from the setup or Play again get, in
/// order (42 once they run out).
Future<void> theNextRoundSeedsAre(WidgetTester tester, String seeds) async =>
    nextSeeds().addAll([for (final s in seeds.split(',')) int.parse(s.trim())]);
