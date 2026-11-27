import 'dart:async';

import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/src/auth_tokens.dart';
import 'package:mc_session/src/session_ports.dart';
import 'package:mc_storage/mc_storage.dart';

/// The session, kept on a [FileStore] under one key (as `SearchHistory`
/// does): a missing, corrupt or unreadable value reads as signed out, and the
/// next write replaces it.
///
/// Use one instance per store key. Saves of one instance are serialised in
/// call order, so a fast sign-in then sign-out never leaves the store
/// disagreeing with memory. Two instances on the same key do not see each
/// other's changes (accepted).
///
/// The store is plain JSON in the app's support directory. That is enough for
/// a mock identity; a real one must move the tokens to the Keychain.
final class Session implements SessionReader, SessionWriter, SessionEpochs {
  /// The store key the session lives under unless another is given.
  static const String defaultKey = 'session';

  Session._(this._store, this._bus, this._key, this._current);

  /// Opens the session saved under [key], if any.
  static Future<Session> restore(
    FileStore store, {
    EventBus? bus,
    String key = defaultKey,
  }) async {
    final read = await store.read(key);
    return Session._(store, bus, key, read.fold(_decode, (_) => null));
  }

  /// A signed-out session on [store], without reading it. Only right when
  /// nothing was ever saved there; [restore] is the general case.
  factory Session.empty(
    FileStore store, {
    EventBus? bus,
    String key = defaultKey,
  }) => Session._(store, bus, key, null);

  static _Active? _decode(Object? json) {
    final tokens = AuthTokens.fromJson(json);
    if (tokens != null &&
        json is Map &&
        json['userId'] is String &&
        (json['userId'] as String).isNotEmpty) {
      return _Active(json['userId'] as String, tokens);
    }
    return null;
  }

  final FileStore _store;
  final EventBus? _bus;
  final String _key;
  final StreamController<AuthStatus> _changes =
      StreamController<AuthStatus>.broadcast();
  final StreamController<int> _epochs = StreamController<int>.broadcast();

  _Active? _current;
  int _epoch = 0;
  // Created on first use, in the caller's zone: a future made at boot under
  // fake async would never complete for a caller that runs in real time.
  Future<void>? _tail;

  @override
  AuthStatus get status =>
      _current == null ? AuthStatus.signedOut : AuthStatus.signedIn;

  @override
  bool get isSignedIn => _current != null;

  @override
  String? get userId => _current?.userId;

  @override
  String? get accessToken => _current?.tokens.accessToken;

  @override
  String? get refreshToken => _current?.tokens.refreshToken;

  @override
  int get epoch => _epoch;

  @override
  Stream<AuthStatus> get authState => _changes.stream;

  @override
  Stream<int> get epochChanges => _epochs.stream;

  @override
  Future<Result<void, StorageFailure>> signIn({
    required String userId,
    required AuthTokens tokens,
  }) {
    final active = _Active(userId, tokens);
    final changed = _current?.userId != userId;
    _current = active;
    _epoch++;
    _announceEpoch();
    if (changed) {
      _announce(AuthStatus.signedIn);
    }
    return _enqueue(() => _store.write(_key, active.toJson()));
  }

  @override
  Future<Result<void, StorageFailure>> updateTokens(
    AuthTokens tokens, {
    int? epoch,
  }) {
    final current = _current;
    if (current == null || (epoch != null && epoch != _epoch)) {
      return Future.value(success(null));
    }
    final active = _Active(current.userId, tokens);
    _current = active;
    return _enqueue(() => _store.write(_key, active.toJson()));
  }

  @override
  Future<Result<void, StorageFailure>> signOut({int? ifEpoch}) {
    if (ifEpoch != null && ifEpoch != _epoch) {
      return Future.value(success(null));
    }
    final wasSignedIn = _current != null;
    _current = null;
    if (wasSignedIn) {
      _epoch++;
      _announceEpoch();
      _announce(AuthStatus.signedOut);
    }
    return _enqueue(() => _store.delete(_key));
  }

  /// Closes [authState]. The saved value stays.
  Future<void> dispose() async {
    unawaited(_epochs.close());
    await _changes.close();
  }

  void _announceEpoch() {
    if (!_epochs.isClosed) {
      _epochs.add(_epoch);
    }
  }

  void _announce(AuthStatus status) {
    if (!_changes.isClosed) {
      _changes.add(status);
    }
    _bus?.publish(SessionChanged(status));
  }

  Future<Result<void, StorageFailure>> _enqueue(
    Future<Result<void, StorageFailure>> Function() action,
  ) {
    final run = (_tail ?? Future<void>.value()).then((_) => action());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}

final class _Active {
  const _Active(this.userId, this.tokens);

  final String userId;
  final AuthTokens tokens;

  Map<String, Object?> toJson() => {'userId': userId, ...tokens.toJson()};
}
