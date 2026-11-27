import 'dart:async';

import 'package:dio/dio.dart';
import 'package:mc_appearance/src/appearance_ports.dart';
import 'package:mc_appearance/src/appearance_preferences.dart';
import 'package:mc_appearance/src/appearance_snapshot.dart';
import 'package:mc_appearance/src/appearance_store.dart';
import 'package:mc_appearance/src/preferences_api.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

/// The app-wide appearance: one instance in the root container (ADR-0013).
///
/// ## Where it lives
/// - **On the device**, always: every change is saved (synchronously, under
///   `appearance` in the `FileStore`) before [change] returns. Signed out,
///   the device's copy is the truth.
/// - **In the account**, when signed in: `GET` and `PATCH
///   /v1/me/preferences`, with `ifVersion`.
///
/// ## The merge rule
/// The device remembers which settings were changed here and not yet
/// confirmed by the account (**pending**), and for whom. Whenever a session
/// starts (a sign-in, a launch signed in, a user switch, a same-user
/// re-sign-in), the account's copy is read and **the account wins, except
/// for the pending settings**, which are re-applied on top and sent:
/// - pending settings of the user now signed in, or made while signed out,
///   go to this account;
/// - pending settings of **another** user are dropped, so A's unsynced
///   change never reaches B's account.
///
/// Signing out keeps the shown values on the device (they are the device's
/// now) and drops what was still pending: a session ending is not a change
/// the user made. A switch A → B is a sign-out then a sign-in: the values
/// shown until B's copy arrives are A's last ones, and B's copy replaces
/// them.
///
/// ## Writes
/// One request at a time. A `PATCH` sends only the pending settings, with
/// the version last read, pinned to the session epoch it was checked in
/// (`authPinned`, T-0050). On a `409` the account's `current` is taken and
/// only the user's change is re-applied on it, and sent once more; a second
/// `409` ends `offline`. A change made while a request is out is sent after
/// it.
///
/// ## The session epoch
/// Every answer is checked against the epoch it was asked in, after the
/// await and before anything is applied or written: an answer for a session
/// that is gone changes nothing.
final class Appearance implements AppearanceSettings {
  Appearance._({
    required Dio dio,
    required SessionReader session,
    required AppearanceStore store,
    required Monitoring? monitoring,
    required AppearanceRecord? restored,
    required StorageFailure? restoreFailure,
    required bool followAccount,
  }) : _followAccount = followAccount,
       _api = PreferencesApi(dio),
       _session = session,
       _store = store,
       _monitoring = monitoring {
    if (restored != null) {
      _preferences = restored.preferences;
      _pending.addAll(restored.pending);
      _pendingFor = restored.pendingFor;
      _saved = restored;
    }
    if (restoreFailure != null) {
      _warn(
        'the saved appearance was unreadable, using the defaults: '
        '$restoreFailure',
      );
    }
  }

  /// Builds the appearance on [store], reading what was saved there
  /// (synchronously: boot never awaits it). Call [start] to follow the
  /// session.
  ///
  /// With [followAccount] false it keeps the device's copy only, as if
  /// nobody were ever signed in: no request, status `local` (the test
  /// container's default, so a feature test that signs in sends no
  /// preferences read it never asked for; T-0063).
  factory Appearance.open({
    required Dio dio,
    required SessionReader session,
    required FileStore store,
    Monitoring? monitoring,
    bool followAccount = true,
  }) {
    final appearanceStore = AppearanceStore(store);
    final read = appearanceStore.read();
    return Appearance._(
      dio: dio,
      session: session,
      store: appearanceStore,
      monitoring: monitoring,
      restored: read.getOrNull(),
      restoreFailure: read.fold((_) => null, (f) => f),
      followAccount: followAccount,
    );
  }

  final bool _followAccount;
  final PreferencesApi _api;
  final SessionReader _session;
  final AppearanceStore _store;
  final Monitoring? _monitoring;

  final StreamController<AppearanceSnapshot> _changes =
      StreamController<AppearanceSnapshot>.broadcast();

  AppearancePreferences _preferences = AppearancePreferences.defaults;
  final Set<AppearanceSetting> _pending = {};
  String? _pendingFor;
  AppearanceRecord? _saved;
  StorageFailure? _saveFailure;
  AppearanceSyncStatus _status = AppearanceSyncStatus.local;
  AppearanceSnapshot? _last;

  /// The account's copy as last read or written in [_seenEpoch]; null until
  /// read (and after a failure, so the next sync reads it again).
  PreferencesCopy? _account;

  int? _seenEpoch;
  StreamSubscription<AuthStatus>? _authSubscription;
  StreamSubscription<int>? _epochSubscription;
  bool _disposed = false;

  /// The sync run of the current epoch, while it runs.
  Future<void>? _run;
  int? _runEpoch;

  @override
  AppearanceSnapshot get snapshot => AppearanceSnapshot(
    preferences: _preferences,
    status: _status,
    saveFailure: _saveFailure,
  );

  @override
  Stream<AppearanceSnapshot> get changes => _changes.stream;

  /// Follows the session from now on and syncs for the current one.
  void start() {
    if (!_followAccount) {
      return;
    }
    _authSubscription = _session.authState.listen((_) => _observeEpoch());
    // A same-user re-sign-in starts an epoch without an `authState` event.
    final Object session = _session;
    if (session is SessionEpochs) {
      _epochSubscription = session.epochChanges.listen((_) => _observeEpoch());
    }
    _observeEpoch();
  }

  /// Completes when the sync run of the current session epoch (if any) has
  /// ended. A run of an older epoch is not waited for: whatever it still
  /// waits on, its answer changes nothing. For tests.
  Future<void> settled() async {
    for (
      var run = _run;
      run != null && _runEpoch == _session.epoch;
      run = _run
    ) {
      await run;
    }
  }

  /// Stops following the session; answers still on their way change
  /// nothing. Subscriptions are cancelled without waiting (a cancel future
  /// from the root zone never completes under fake async, F-0052).
  Future<void> dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    unawaited(_epochSubscription?.cancel());
    unawaited(_changes.close());
    return Future<void>.value();
  }

  // --- changes -------------------------------------------------------------

  @override
  Future<void> change({
    AppearanceThemeMode? themeMode,
    AppearanceDensity? density,
    bool? reduceMotion,
  }) => _changeTo(
    _preferences.copyWith(
      themeMode: themeMode,
      density: density,
      reduceMotion: reduceMotion,
    ),
  );

  @override
  Future<void> reset() => _changeTo(AppearancePreferences.defaults);

  Future<void> _changeTo(AppearancePreferences next) {
    if (_disposed) {
      return Future<void>.value();
    }
    // A session change not heard of yet is handled first, so the change
    // belongs to the session that is current now.
    _observeEpoch();
    final changed = next.differencesFrom(_preferences);
    if (changed.isEmpty) {
      return Future<void>.value();
    }
    _preferences = next;
    _pending.addAll(changed);
    // Signed in, the change is this user's; signed out, the device's (it
    // goes to whoever signs in next).
    _pendingFor = _userId;
    _save();
    if (_userId == null) {
      _publish();
      return Future<void>.value();
    }
    _status = AppearanceSyncStatus.pending;
    _publish();
    return _sync();
  }

  @override
  Future<void> retry() {
    if (_disposed) {
      return Future<void>.value();
    }
    _observeEpoch();
    if (_saveFailure != null) {
      _save();
      _publish();
    }
    if (_userId == null || _status != AppearanceSyncStatus.offline) {
      return Future<void>.value();
    }
    // Read the account's copy again: it may have moved while we were out.
    _account = null;
    _status = AppearanceSyncStatus.pending;
    _publish();
    return _sync();
  }

  // --- the session -----------------------------------------------------------

  /// Who is signed in, as far as the account sync goes.
  String? get _userId => _followAccount ? _session.userId : null;

  void _observeEpoch() {
    final epoch = _session.epoch;
    if (_disposed || !_followAccount || epoch == _seenEpoch) {
      return;
    }
    _seenEpoch = epoch;
    _account = null;
    final userId = _session.userId;
    if (userId == null) {
      // Signed out: the shown values stay, and are the device's now.
      if (_pendingFor != null) {
        _pending.clear();
        _pendingFor = null;
        _save();
      }
      _status = AppearanceSyncStatus.local;
      _publish();
      return;
    }
    if (_pendingFor != null && _pendingFor != userId) {
      // Another user's unsynced change never reaches this account.
      _pending.clear();
    }
    if (_pending.isEmpty) {
      _pendingFor = null;
    } else {
      // This user's own, or made while signed out: it goes to this account.
      _pendingFor = userId;
    }
    _save();
    _status = AppearanceSyncStatus.pending;
    _publish();
    unawaited(_sync());
  }

  bool _isCurrent(int epoch) => !_disposed && _session.epoch == epoch;

  // --- sync ------------------------------------------------------------------

  /// Joins the run of the current epoch, or starts one. A run picks up
  /// whatever is pending when each request ends, so a change made while a
  /// request is out is sent next.
  Future<void> _sync() {
    final epoch = _session.epoch;
    if (_run case final run? when _runEpoch == epoch) {
      return run;
    }
    _runEpoch = epoch;
    late final Future<void> run;
    run = _runSync(epoch).whenComplete(() {
      if (identical(_run, run)) {
        _run = null;
        _runEpoch = null;
      }
    });
    _run = run;
    return run;
  }

  Future<void> _runSync(int epoch) async {
    var conflicts = 0;
    var tookOtherChanges = false;
    while (true) {
      var account = _account;
      if (account == null) {
        final read = await _api.read();
        // After the await, before any write.
        if (!_isCurrent(epoch)) {
          return;
        }
        account = read.getOrNull();
        if (account == null) {
          _fail('read', read.fold((_) => '', (f) => f.message));
          return;
        }
        _takeAccount(account);
      }
      if (_pending.isEmpty) {
        _status = tookOtherChanges
            ? AppearanceSyncStatus.conflictResolved
            : AppearanceSyncStatus.synced;
        _publish();
        return;
      }
      final sending = Set.of(_pending);
      final sent = _preferences;
      final outcome = await _api.write(
        epoch: epoch,
        ifVersion: account.version,
        values: sent,
        settings: sending,
      );
      if (!_isCurrent(epoch)) {
        return;
      }
      switch (outcome) {
        case PatchSaved(:final copy):
          // Confirmed, unless the user changed it again meanwhile.
          _pending.removeWhere(
            (s) =>
                sending.contains(s) &&
                _preferences.wireValue(s) == sent.wireValue(s),
          );
          if (_pending.isEmpty) {
            _pendingFor = null;
          }
          _takeAccount(copy);
        case PatchConflict(:final current):
          conflicts++;
          final before = account.preferences;
          // Another device's change is kept; only ours goes on top.
          if (current.preferences
              .differencesFrom(before)
              .difference(_pending)
              .isNotEmpty) {
            tookOtherChanges = true;
          }
          _takeAccount(current);
          if (conflicts > 1) {
            _fail('write', 'a second version conflict');
            return;
          }
        case PatchFailed(:final failure):
          _fail('write', failure.message);
          return;
      }
    }
  }

  /// The account holds [copy]: it wins, except for the pending settings.
  void _takeAccount(PreferencesCopy copy) {
    _account = copy;
    _preferences = copy.preferences.overlay(_preferences, _pending);
    _save();
    _publish();
  }

  void _fail(String what, String message) {
    _account = null;
    _status = AppearanceSyncStatus.offline;
    _publish();
    _warn('the $what of the account preferences failed: $message');
  }

  // --- the device --------------------------------------------------------------

  /// Saves the device's copy if it changed. Synchronous, so no save is ever
  /// still running.
  void _save() {
    final record = AppearanceRecord(
      preferences: _preferences,
      pending: Set.of(_pending),
      pendingFor: _pendingFor,
    );
    // Nothing saved reads as the defaults with nothing pending.
    final saved =
        _saved ??
        const AppearanceRecord(
          preferences: AppearancePreferences.defaults,
        );
    if (_saveFailure == null &&
        saved.preferences == record.preferences &&
        saved.pendingFor == record.pendingFor &&
        saved.pending.length == record.pending.length &&
        saved.pending.containsAll(record.pending)) {
      return;
    }
    _store
        .write(record)
        .fold(
          (_) {
            _saved = record;
            _saveFailure = null;
          },
          (failure) {
            _saveFailure = failure;
            _warn('could not keep the appearance on this device: $failure');
          },
        );
  }

  void _publish() {
    final next = snapshot;
    if (next == _last || _changes.isClosed) {
      return;
    }
    _last = next;
    _changes.add(next);
  }

  void _warn(String message) => unawaited(
    _monitoring?.log('appearance: $message', level: LogLevel.warning),
  );
}
