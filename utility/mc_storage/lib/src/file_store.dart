import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mc_prelude/mc_prelude.dart';

/// A storage failure: unreadable, corrupt or unwritable data.
class StorageFailure implements Exception {
  const StorageFailure(this.key, this.message);
  final String key;
  final String message;

  @override
  String toString() => 'StorageFailure($key): $message';
}

/// Key-value store, one JSON file per key under [directory] (dart:io only,
/// no plugins). Writes go to a temp file and are renamed into place, and
/// writes and deletes of one key are serialised, so a crash or overlapping
/// writes never leave a half-written value.
class FileStore {
  FileStore(this.directory);

  final Directory directory;

  final Map<String, Future<void>> _tails = <String, Future<void>>{};
  int _tempCounter = 0;

  /// Hex of the UTF-8 key: safe on case-insensitive file systems.
  File _file(String key) {
    final hex = utf8
        .encode(key)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return File('${directory.path}/$hex.json');
  }

  Future<T> _serialised<T>(String key, Future<T> Function() action) {
    final previous = _tails[key] ?? Future<void>.value();
    final run = previous.then((_) => action());
    final tail = run.then<void>((_) {}, onError: (Object _) {});
    _tails[key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[key], tail)) {
          _tails.remove(key);
        }
      }),
    );
    return run;
  }

  /// Writes [value] (any JSON-encodable value) under [key].
  Future<Result<void, StorageFailure>> write(String key, Object? value) =>
      _serialised(key, () async {
        try {
          await directory.create(recursive: true);
          final target = _file(key);
          final temp = File('${target.path}.${_tempCounter++}.tmp');
          await temp.writeAsString(jsonEncode(value), flush: true);
          await temp.rename(target.path);
          return success<void, StorageFailure>(null);
        } on Object catch (e) {
          return failure<void, StorageFailure>(
            StorageFailure(key, 'write failed: $e'),
          );
        }
      });

  /// Whether a value is saved under [key], without any asynchronous I/O (a
  /// file that exists may still be corrupt). For boot code that must not
  /// await real I/O.
  bool existsSync(String key) => _file(key).existsSync();

  /// The value under [key]; success(null) when absent, a failure when the
  /// file is corrupt.
  Future<Result<Object?, StorageFailure>> read(String key) async {
    try {
      return success(jsonDecode(await _file(key).readAsString()));
    } on PathNotFoundException {
      return success(null);
    } on Object catch (e) {
      return failure(StorageFailure(key, 'corrupt or unreadable: $e'));
    }
  }

  /// Removes [key]; deleting an absent key succeeds.
  Future<Result<void, StorageFailure>> delete(String key) =>
      _serialised(key, () async {
        try {
          await _file(key).delete();
          return success<void, StorageFailure>(null);
        } on PathNotFoundException {
          return success<void, StorageFailure>(null);
        } on Object catch (e) {
          return failure<void, StorageFailure>(
            StorageFailure(key, 'delete failed: $e'),
          );
        }
      });
}
