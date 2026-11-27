import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the app can no longer write to storage
///
/// From now on every write and delete of `mc_storage` fails, as on a full or
/// read-only disk, while what is saved can still be read. The session's
/// storage directory becomes a link to a read-only copy of itself (`chmod
/// 555`), so no file can be created, renamed or removed in it. The session
/// deletes the link when the test ends; the copy is made writable and
/// removed in a tear-down.
Future<void> theAppCanNoLongerWriteToStorage(WidgetTester tester) async {
  final directory = McTestSession.current.storageDirectory;
  final readOnly = Directory.systemTemp.createTempSync('mc_storage_ro_');
  if (directory.existsSync()) {
    for (final entry in directory.listSync()) {
      if (entry is File) {
        entry.copySync('${readOnly.path}/${entry.uri.pathSegments.last}');
      }
    }
    directory.deleteSync(recursive: true);
  }
  Link(directory.path).createSync(readOnly.path);
  _chmod('555', readOnly);
  addTearDown(() {
    _chmod('755', readOnly);
    if (readOnly.existsSync()) {
      readOnly.deleteSync(recursive: true);
    }
    final link = Link(directory.path);
    if (link.existsSync()) {
      link.deleteSync();
    }
  });
}

void _chmod(String mode, Directory directory) {
  final result = Process.runSync('chmod', [mode, directory.path]);
  if (result.exitCode != 0) {
    fail('chmod $mode ${directory.path} failed: ${result.stderr}');
  }
}
