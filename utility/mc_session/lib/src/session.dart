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
final class Session implements SessionReader, SessionWriter {
  Session._(this._store, this._bus, this._key, this._current);

  /// Opens the session saved under [key], if any.
  static Future<Session> restore(
    FileStore store, {
    EventBus? bus,
    String key = 'session',
  }) async {
    final read = await store.read(key);
    return Session._(store, bus, key, read.fold(_decode, (_) => null));
  }

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

  _Active? _current;
  Future<void> _tail = Future<void>.value();

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
  Stream<AuthStatus> get authState => _changes.stream;

  @override
  Future<Result<void, StorageFailure>> signIn({
    required String userId,
    required AuthTokens tokens,
  }) {
    final active = _Active(userId, tokens);
    _current = active;
    _announce(AuthStatus.signedIn);
    return _enqueue(() => _store.write(_key, active.toJson()));
  }

  @override
  Future<Result<void, StorageFailure>> updateTokens(AuthTokens tokens) {
    final current = _current;
    if (current == null) {
      return Future.value(success(null));
    }
    final active = _Active(current.userId, tokens);
    _current = active;
    return _enqueue(() => _store.write(_key, active.toJson()));
  }

  @override
  Future<Result<void, StorageFailure>> signOut() {
    final wasSignedIn = _current != null;
    _current = null;
    if (wasSignedIn) {
      _announce(AuthStatus.signedOut);
    }
    return _enqueue(() => _store.delete(_key));
  }

  /// Closes [authState]. The saved value stays.
  Future<void> dispose() => _changes.close();

  void _announce(AuthStatus status) {
    if (!_changes.isClosed) {
      _changes.add(status);
    }
    _bus?.publish(SessionChanged(status));
  }

  Future<Result<void, StorageFailure>> _enqueue(
    Future<Result<void, StorageFailure>> Function() action,
  ) {
    final run = _tail.then((_) => action());
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
