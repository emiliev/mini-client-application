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
/// no plugins).
class FileStore {
  FileStore(this.directory);

  final Directory directory;

  File _file(String key) =>
      File('${directory.path}/${Uri.encodeComponent(key)}.json');

  /// Writes [value] (any JSON-encodable value) under [key].
  Future<Result<void, StorageFailure>> write(String key, Object? value) async {
    try {
      await directory.create(recursive: true);
      await _file(key).writeAsString(jsonEncode(value), flush: true);
      return success(null);
    } on Object catch (e) {
      return failure(StorageFailure(key, 'write failed: $e'));
    }
  }

  /// The value under [key]; success(null) when absent, a failure when the
  /// file is corrupt.
  Future<Result<Object?, StorageFailure>> read(String key) async {
    final file = _file(key);
    try {
      if (!file.existsSync()) {
        return success(null);
      }
      return success(jsonDecode(await file.readAsString()));
    } on Object catch (e) {
      return failure(StorageFailure(key, 'corrupt or unreadable: $e'));
    }
  }

  Future<Result<void, StorageFailure>> delete(String key) async {
    try {
      final file = _file(key);
      if (file.existsSync()) {
        await file.delete();
      }
      return success(null);
    } on Object catch (e) {
      return failure(StorageFailure(key, 'delete failed: $e'));
    }
  }
}
