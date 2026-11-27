import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: I choose the theme mode {'Dark'}
///
/// Taps the theme control's segment with this label.
Future<void> iChooseTheThemeMode(WidgetTester tester, String label) =>
    tapSegment(tester, themeModeKey('system'), label);
