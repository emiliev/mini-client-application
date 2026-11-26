import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the app can no longer write to storage
///
/// From now on every read and write of `mc_storage` fails, as on a full or
/// broken disk: the session's storage directory is replaced by a plain file,
/// so nothing can be created under it. What the app already read stays in
/// memory. The file is removed when the test ends.
Future<void> theAppCanNoLongerWriteToStorage(WidgetTester tester) async {
  final directory = McTestSession.current.storageDirectory;
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
  final blocker = File(directory.path)..writeAsStringSync('not a directory');
  addTearDown(() {
    if (blocker.existsSync()) {
      blocker.deleteSync();
    }
  });
}
