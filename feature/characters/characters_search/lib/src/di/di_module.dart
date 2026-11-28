import 'package:injectable/injectable.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_storage/mc_storage.dart';

/// The `FileStore` key of the recent character searches. Every flow instance
/// reads and writes the same key, so the list survives the flow (and the
/// app). It is this feature's own key: the global search keeps its own list.
const String searchHistoryStoreKey = 'characters_search.history';

/// How many recent searches are kept.
const int searchHistoryCap = 10;

/// Kit types this feature registers itself (plan 01 §3.3, `di_module.dart`):
/// `mc_paging`'s `SearchHistory` is not injectable-annotated.
@module
abstract class CharactersSearchModule {
  /// One history per flow scope, so its adds and clears are serialised
  /// (`SearchHistory`'s queue is per instance). Two flows open at once on the
  /// same key read and write independently, which the kit accepts.
  @lazySingleton
  SearchHistory searchHistory(FileStore store) =>
      SearchHistory(store, cap: searchHistoryCap, key: searchHistoryStoreKey);
}
