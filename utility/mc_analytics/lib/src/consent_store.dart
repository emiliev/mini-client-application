import 'package:mc_analytics/src/consent.dart';
import 'package:mc_storage/mc_storage.dart';

/// Keeps the consent choice in `mc_storage`, so it survives a restart.
class ConsentStore {
  ConsentStore(this._store, {this.key = defaultKey});

  /// The storage key of the saved choice.
  static const String defaultKey = 'analytics_consent';

  final FileStore _store;
  final String key;

  /// The saved consent, or [fallback] when nothing was saved.
  ///
  /// A saved value that cannot be read, or that names no consent, gives
  /// `unknown`, never [fallback]: a damaged file must not turn a saved
  /// `denied` into a granted default.
  ///
  /// Reading is real file I/O, so it is skipped when no file exists (a first
  /// launch, and every widget test with a fresh temp directory): boot stays
  /// free of I/O that a `testWidgets` body under fake async cannot await
  /// (F-0038), as `SessionDIInitializer` does.
  Future<AnalyticsConsent> restore(AnalyticsConsent fallback) async {
    bool saved;
    try {
      saved = _store.existsSync(key);
    } on Object {
      saved = true;
    }
    if (!saved) {
      return fallback;
    }
    final read = await _store.read(key);
    return read.fold(
      (value) => value == null ? fallback : AnalyticsConsent.parse(value),
      (_) => AnalyticsConsent.unknown,
    );
  }

  /// Saves [consent]. Throws the [StorageFailure] when it cannot.
  Future<void> save(AnalyticsConsent consent) async {
    final written = await _store.write(key, consent.name);
    written.fold((_) {}, (failure) => throw failure);
  }
}
