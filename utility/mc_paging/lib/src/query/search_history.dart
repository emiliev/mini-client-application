import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_storage/mc_storage.dart';

/// Recent search queries on a [FileStore]: most recent first, no
/// duplicates, at most [cap] kept.
final class SearchHistory {
  SearchHistory(this._store, {this.cap = 10, this.key = 'search_history'})
    : assert(cap > 0, 'cap must be positive');

  final FileStore _store;
  final int cap;
  final String key;

  Future<void> _tail = Future<void>.value();

  /// The saved queries, most recent first. A missing or unreadable value
  /// is an empty list; a failed read is a failure.
  Future<Result<List<String>, StorageFailure>> load() async =>
      (await _store.read(key)).map(_decode);

  /// Moves [query] to the front. A blank query changes nothing. Adds are
  /// serialised, so overlapping calls keep every query.
  Future<Result<List<String>, StorageFailure>> add(String query) {
    final text = query.trim();
    final run = _tail.then((_) => _add(text));
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Removes every saved query.
  Future<Result<void, StorageFailure>> clear() => _store.delete(key);

  Future<Result<List<String>, StorageFailure>> _add(String text) async {
    final current = await load();
    return current.asyncFlatMap((saved) async {
      if (text.isEmpty) {
        return success(saved);
      }
      final updated = [
        text,
        ...saved.where((q) => q != text),
      ].take(cap).toList();
      return (await _store.write(key, updated)).map((_) => updated);
    });
  }

  static List<String> _decode(Object? json) =>
      json is List ? json.whereType<String>().toList() : <String>[];
}
