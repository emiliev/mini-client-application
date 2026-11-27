import 'package:mc_appearance/src/appearance_preferences.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_storage/mc_storage.dart';

/// The `FileStore` key the device's copy lives under.
const String appearanceStoreKey = 'appearance';

/// What the device keeps (ADR-0013): the preferences in use; the settings
/// changed here that the account has not confirmed yet, with the user they
/// belong to (null: changed while signed out, so they go to whoever signs in
/// next); and the account version this device last saw, with its user.
///
/// ```json
/// {"themeMode": "dark", "density": "comfortable", "reduceMotion": false,
///  "pending": ["themeMode"], "pendingFor": "u-101",
///  "seenVersion": 3, "seenFor": "u-101"}
/// ```
final class AppearanceRecord {
  const AppearanceRecord({
    required this.preferences,
    this.pending = const {},
    this.pendingFor,
    this.seenVersion,
    this.seenFor,
  });

  final AppearancePreferences preferences;
  final Set<AppearanceSetting> pending;
  final String? pendingFor;

  /// The account version this device last read or wrote for [seenFor].
  final int? seenVersion;
  final String? seenFor;

  /// Whether [other] holds the same values.
  bool sameAs(AppearanceRecord other) =>
      other.preferences == preferences &&
      other.pendingFor == pendingFor &&
      other.pending.length == pending.length &&
      other.pending.containsAll(pending) &&
      other.seenVersion == seenVersion &&
      other.seenFor == seenFor;

  Map<String, Object?> toJson() => {
    ...preferences.toWire(),
    'pending': [
      for (final setting in AppearanceSetting.values)
        if (pending.contains(setting)) setting.wireKey,
    ],
    'pendingFor': pendingFor,
    'seenVersion': seenVersion,
    'seenFor': seenFor,
  };

  /// The record in [json], or null when its preferences cannot be read.
  /// Unknown pending keys are dropped, a `pendingFor` that is not a
  /// non-empty string counts as none, and so does a seen version without
  /// its user.
  static AppearanceRecord? fromJson(Object? json) {
    final preferences = AppearancePreferences.fromWire(json);
    if (preferences == null || json is! Map) {
      return null;
    }
    final pending = json['pending'];
    final owner = json['pendingFor'];
    final seenVersion = json['seenVersion'];
    final seenFor = json['seenFor'];
    final seen = seenVersion is int && seenFor is String && seenFor.isNotEmpty;
    return AppearanceRecord(
      preferences: preferences,
      pending: {
        if (pending is List)
          for (final key in pending)
            if (AppearanceSetting.fromWireKey(key) case final setting?) setting,
      },
      pendingFor: owner is String && owner.isNotEmpty ? owner : null,
      seenVersion: seen ? seenVersion : null,
      seenFor: seen ? seenFor : null,
    );
  }
}

/// The preferences saved on [store], or null when none are saved or they
/// cannot be read. Synchronous, so the app shell can paint its boot page in
/// the saved theme before the appearance exists (review round).
AppearancePreferences? savedAppearance(FileStore store) => AppearanceStore(
  store,
).read().fold((record) => record?.preferences, (_) => null);

/// Reads and writes the record **synchronously** (`FileStore.readSync`,
/// `writeSync`): the value is tiny, it must be known before the first
/// frame, and a write that is still running can never race the next one or
/// the removal of the directory (F-0050 §7, F-0063).
final class AppearanceStore {
  const AppearanceStore(this._store);

  final FileStore _store;

  /// The saved record; null when none is saved. A corrupt or unreadable one
  /// is reported as a failure, and the caller starts from the defaults.
  Result<AppearanceRecord?, StorageFailure> read() =>
      _store.readSync(appearanceStoreKey).fold((json) {
        if (json == null) {
          return success(null);
        }
        final record = AppearanceRecord.fromJson(json);
        return record == null
            ? failure(
                StorageFailure(appearanceStoreKey, 'not an appearance: $json'),
              )
            : success(record);
      }, failure);

  Result<void, StorageFailure> write(AppearanceRecord record) =>
      _store.writeSync(appearanceStoreKey, record.toJson());
}
