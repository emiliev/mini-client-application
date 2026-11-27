import 'package:mc_appearance/src/appearance_preferences.dart';
import 'package:mc_storage/mc_storage.dart';

/// Where the shown preferences stand against the user's account (ADR-0013).
enum AppearanceSyncStatus {
  /// Signed out: the preferences live on this device only.
  local,

  /// Signed in, and a read or a write of the account's copy is on its way.
  pending,

  /// Signed in, and the account holds exactly what is shown.
  synced,

  /// Signed in, but the last read or write failed. What is shown is kept
  /// on the device and goes to the account on the next sync (a change, or
  /// [AppearanceSettings.retry]).
  offline,

  /// Signed in and synced, after another device had changed the account's
  /// copy in between: its change was kept, and the user's own change was
  /// applied on top of it (a `409` re-applied).
  conflictResolved,
}

/// What the app shows now, and how it stands. An immutable value.
final class AppearanceSnapshot {
  const AppearanceSnapshot({
    required this.preferences,
    required this.status,
    this.saveFailure,
  });

  final AppearancePreferences preferences;
  final AppearanceSyncStatus status;

  /// Set when the device could not keep the preferences (the last local
  /// save failed): they apply now, but would not survive a restart. Null
  /// once a save succeeds.
  final StorageFailure? saveFailure;

  @override
  bool operator ==(Object other) =>
      other is AppearanceSnapshot &&
      other.preferences == preferences &&
      other.status == status &&
      identical(other.saveFailure, saveFailure);

  @override
  int get hashCode => Object.hash(preferences, status, saveFailure);

  @override
  String toString() =>
      'AppearanceSnapshot($preferences, ${status.name}'
      '${saveFailure == null ? '' : ', save failed'})';
}
