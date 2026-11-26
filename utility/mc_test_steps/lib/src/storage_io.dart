import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Lets the app's real file I/O (`mc_storage`) run to the end inside a
/// `testWidgets` body, without settling the screen.
///
/// A `testWidgets` body runs on fake time, and a real read or write only
/// completes once real time passes (F-0038 fact 1). Each `dart:io` call is
/// one hop: real time completes it, then a pump runs the code that awaited
/// it, which may start the next call. So this alternates `runAsync` (real
/// time) and `pump`:
///
/// 1. 10 rounds of 20 ms, as `the app finishes writing to storage` always
///    did;
/// 2. then rounds of 2 ms until the session's storage directory (names,
///    sizes, modification times) has not changed for 25 rounds in a row, so
///    a chain of queued writes (each a read, a write and a rename) also
///    finishes. It fails after 1000 rounds of change.
Future<void> mcFinishStorageIo(WidgetTester tester) async {
  for (var round = 0; round < 10; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  final directory = McTestSession.current.storageDirectory;
  var last = _snapshot(directory);
  var unchanged = 0;
  for (var round = 0; unchanged < 25; round++) {
    if (round >= 1000) {
      fail('the storage directory kept changing for 1000 rounds');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
    final now = _snapshot(directory);
    unchanged = now == last ? unchanged + 1 : 0;
    last = now;
  }
}

/// What the directory holds, synchronously (no fake-time await).
/// A file renamed away between the listing and its `stat` counts as a
/// change (the snapshot is then unique).
String _snapshot(Directory directory) {
  try {
    if (!directory.existsSync()) {
      return '';
    }
    final entries = directory.listSync(recursive: true).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return [
      for (final entry in entries)
        if (entry.statSync() case final stat)
          '${entry.path}|${stat.type}|${stat.size}|'
              '${stat.modified.microsecondsSinceEpoch}',
    ].join('\n');
  } on FileSystemException catch (e) {
    return 'changing: $e ${DateTime.now().microsecondsSinceEpoch}';
  }
}
