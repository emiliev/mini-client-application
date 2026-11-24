import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_storage/mc_storage.dart';

/// Recent search queries on a [FileStore]: most recent first, no
/// duplicates, at most [cap] kept.
///
/// Use one instance per store key. Adds and clears of one instance are
/// serialised; two instances on the same store and key read and write
/// independently, so one can overwrite the other's update (accepted).
final class SearchHistory {
  SearchHistory(this._store, {this.cap = 10, this.key = 'search_history'})
    : assert(cap > 0, 'cap must be positive');

  final FileStore _store;
  final int cap;
  final String key;

  Future<void> _tail = Future<void>.value();

  /// The saved queries, most recent first, at most [cap]. A missing, corrupt
  /// or unreadable value is an empty list, so the next [add] overwrites it.
  Future<Result<List<String>, StorageFailure>> load() async {
    final read = await _store.read(key);
    return success(read.fold(_decode, (_) => <String>[]));
  }

  /// Moves [query] to the front. A blank query changes nothing. Adds and
  /// clears are serialised, so overlapping calls keep every query and run in
  /// call order.
  Future<Result<List<String>, StorageFailure>> add(String query) {
    final text = query.trim();
    return _enqueue(() => _add(text));
  }

  /// Removes every saved query, in order with pending [add] calls.
  Future<Result<void, StorageFailure>> clear() =>
      _enqueue(() => _store.delete(key));

  Future<R> _enqueue<R>(Future<R> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<Result<List<String>, StorageFailure>> _add(String text) async {
    final saved = (await load()).getOrElse(() => <String>[]);
    if (text.isEmpty) {
      return success(saved);
    }
    final updated = [text, ...saved.where((q) => q != text)].take(cap).toList();
    return (await _store.write(key, updated)).map((_) => updated);
  }

  List<String> _decode(Object? json) =>
      json is List ? json.whereType<String>().take(cap).toList() : <String>[];
}
