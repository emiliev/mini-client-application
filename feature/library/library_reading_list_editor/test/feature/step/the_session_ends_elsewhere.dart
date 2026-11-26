import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the session ends elsewhere
///
/// The user signs out from another screen: the real `AuthApi.signOut`,
/// inside `runAsync` (the session clears a real file, F-0038).
Future<void> theSessionEndsElsewhere(WidgetTester tester) =>
    endSessionElsewhere(tester);
