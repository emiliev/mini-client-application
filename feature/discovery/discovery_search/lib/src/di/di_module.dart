import 'package:injectable/injectable.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_storage/mc_storage.dart';

/// The `FileStore` key of the recent searches. Every flow instance reads and
/// writes the same key, so the list survives the flow (and the app).
const String searchHistoryStoreKey = 'discovery_search.history';

/// How many recent searches are kept.
const int searchHistoryCap = 10;

/// Kit types this feature registers itself (plan 01 §3.3, `di_module.dart`):
/// `mc_paging`'s `SearchHistory` is not injectable-annotated.
@module
abstract class DiscoverySearchModule {
  /// One history per flow scope, so its adds and clears are serialised
  /// (`SearchHistory`'s queue is per instance). Two flows open at once on the
  /// same key read and write independently, which the kit accepts.
  @lazySingleton
  SearchHistory searchHistory(FileStore store) =>
      SearchHistory(store, cap: searchHistoryCap, key: searchHistoryStoreKey);
}
