import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I keep playing
///
/// Cancels the quit dialog without moving fake time (the countdown resumes
/// at once, so a settle would count against the question).
Future<void> iKeepPlaying(WidgetTester tester) async {
  await tester.tap(find.byKey(mcCancelButtonKey));
  await landAtOnce(tester);
}
