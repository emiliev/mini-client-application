import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: I choose the density {'Compact'}
///
/// Taps the density control's segment with this label.
Future<void> iChooseTheDensity(WidgetTester tester, String label) =>
    tapSegment(tester, densityKey('comfortable'), label);
