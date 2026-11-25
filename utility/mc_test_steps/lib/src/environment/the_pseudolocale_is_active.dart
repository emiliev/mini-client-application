import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the pseudo-locale is active
///
/// `en_XA` (R24): accented, bracketed and about 40 % longer strings, so text
/// that is not localised or that overflows shows. Set it before the flow
/// opens.
Future<void> thePseudolocaleIsActive(WidgetTester tester) async =>
    McTestSession.current.locale = const Locale('en', 'XA');
