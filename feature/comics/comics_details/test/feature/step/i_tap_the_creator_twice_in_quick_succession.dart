import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the creator {'Esme Garrow'} twice in quick succession
///
/// Two taps on the credit within one frame.
Future<void> iTapTheCreatorTwiceInQuickSuccession(
  WidgetTester tester,
  String name,
) => tapComicTarget(tester, creditRow(name), times: 2);
