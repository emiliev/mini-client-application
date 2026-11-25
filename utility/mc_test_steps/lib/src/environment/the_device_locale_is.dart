import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the device locale is {'de'}
///
/// A language code, optionally with a country (`de`, `en_XA`). Set it before
/// the step that opens the flow; `initFlow` reads it.
Future<void> theDeviceLocaleIs(WidgetTester tester, String tag) async {
  final parts = tag.split(RegExp('[_-]'));
  McTestSession.current.locale = Locale(
    parts.first,
    parts.length > 1 ? parts[1] : null,
  );
}
