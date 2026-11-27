import 'dart:async';

import 'package:app_core/src/links/pending_links.dart';
import 'package:app_core/src/locations/app_locations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_session/mc_session.dart';

/// The sign-in guard of plan 01 §4.2 (T-0066), the router's one `redirect`
/// for protected locations.
///
/// A signed-out user who opens a protected location (a cold link, a link
/// while the app runs, a push) is sent to
/// `/auth/sign-in?from=<where they were going>`. The sign-in screen goes on to
/// `from` once it signed them in. A signed-in user is never redirected.
///
/// The guard is **synchronous and reads the session's memory**, so the
/// decision never waits for storage. [refresh] is the router's
/// `refreshListenable`: it ticks on every sign-out, so the router
/// re-evaluates what is on screen (signing out on `/me/lists/l-1/edit`
/// redirects). It listens to the session only while the router listens to it.
/// It does not tick on a sign-in: nothing on screen needs re-evaluating
/// (the sign-in page leaves by itself), and a refresh that starts with the
/// sign-in restores the stack as it was, which undoes a pop that follows
/// within a few frames (see [_SessionRefresh]).
///
/// **A pushed page is not re-evaluated by a refresh.** go_router restores an
/// imperative page (`push`, what `AppFlows` does) from the saved match list
/// without running `redirect` for it again, so a sign-out on a pushed
/// `/me/lists/l-1/edit` would leave the editor on screen. [bind] gives the
/// guard the router: after a sign-out it looks at the page on top, and sends
/// the user to sign-in (`go`) when that page is protected. The `go` replaces
/// the stack, so every `AppFlows` caller waiting on a page that is gone
/// completes once with null.
final class SignInGuard {
  SignInGuard(this._session) {
    refresh = _SessionRefresh(_session, onSignedOut: _enforce);
  }

  final SessionReader _session;

  /// Ticks when the session ends.
  late final Listenable refresh;

  GoRouter? _router;

  /// Gives the guard the router it protects (once `buildAppRouter` made it).
  void bind(GoRouter router) => _router = router;

  /// After a sign-out: the page on top, if it is protected, goes to sign-in.
  /// Runs after the frame, when a refresh of a page that was not pushed has
  /// already redirected it.
  void _enforce() {
    final router = _router;
    if (router == null) {
      return;
    }
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_session.isSignedIn || !identical(router, _router)) {
          return;
        }
        final config = router.routerDelegate.currentConfiguration;
        if (config.isEmpty) {
          return;
        }
        final last = config.last;
        final top = last is ImperativeRouteMatch
            ? last.matches.uri
            : config.uri;
        final target = redirect(top);
        if (target != null) {
          router.go(target);
        }
      })
      ..scheduleFrame();
  }

  /// The location a signed-out user is sent to for [uri], or null when
  /// nothing is in the way (signed in, or not a protected location).
  String? redirect(Uri uri) {
    if (_session.isSignedIn || !isProtectedLocation(uri)) {
      return null;
    }
    return AppLocations.signIn(from: originalLocationOf(uri));
  }

  /// Protected locations (plan 01 §4.2): `/me/**`, `/library/**` and
  /// `/store/checkout`. Judged on the location as it would be matched: the
  /// path normalised, percent-decoded (twice, so a double encoding is no
  /// way round), and also as written, whatever its case. A blocked entry is
  /// a nuisance for a bad link and never wrong for a good one.
  static bool isProtectedLocation(Uri uri) {
    for (final path in _pathForms(uri)) {
      if (_isProtectedPath(path)) {
        return true;
      }
    }
    return false;
  }

  static bool _isProtectedPath(String path) {
    final lower = path.toLowerCase();
    return _protectedPrefixes.any(
      (prefix) =>
          lower == prefix ||
          lower.startsWith('$prefix/') ||
          lower.startsWith('$prefix?'),
    );
  }

  static const List<String> _protectedPrefixes = [
    '/me',
    '/library',
    '/store/checkout',
  ];

  /// The path as written, normalised, and decoded one and two times, each
  /// normalised again.
  static Iterable<String> _pathForms(Uri uri) sync* {
    var path = uri.path;
    yield path;
    for (var i = 0; i < 3; i++) {
      final next = _decode(path);
      if (next == null) {
        // Not decodable: nothing more to read from it.
        return;
      }
      path = next;
      yield path;
      yield Uri(path: path).normalizePath().path;
    }
  }

  /// [uri] as a location of this app: its path, query and fragment, without
  /// a scheme or host (a link in the running app arrives as
  /// `miniclient://app/me/lists/new`).
  static String originalLocationOf(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    // Written out, not built with `Uri(path:)`, which would encode the `%`
    // of an encoded segment a second time.
    return '${path.startsWith('/') ? path : '/$path'}'
        '${uri.hasQuery ? '?${uri.query}' : ''}'
        '${uri.hasFragment ? '#${uri.fragment}' : ''}';
  }
}

/// Where the sign-in screen goes after it signed the user in: [from] when it
/// is a location of this app, else home (T-0066). The only way a link's
/// `from` becomes a navigation, so nothing else can be reached through it
/// (no open redirect).
///
/// A location of this app is either a path (starting with exactly one `/`)
/// or `miniclient://app/…`. Everything else gives home: another scheme or
/// host, a scheme-relative `//evil`, a backslash, a control character, a
/// user-info or port, a percent-encoded form of any of those (decoded up to
/// five times), and the sign-in screen itself (it would loop).
String safeSignInTarget(String? from) {
  const home = AppLocations.home;
  if (from == null ||
      from.isEmpty ||
      _hasForbiddenCharacter(from, space: true)) {
    return home;
  }
  final uri = Uri.tryParse(from);
  if (uri == null) {
    return home;
  }
  if (uri.hasScheme) {
    // Only `miniclient://app/…`, with nothing else in its authority.
    if (uri.scheme != LinkScheme.app.scheme ||
        uri.host != LinkScheme.app.host ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return home;
    }
  } else if (uri.hasAuthority || !uri.path.startsWith('/')) {
    // `//evil`, `///x`, or a relative reference.
    return home;
  }
  final path = uri.path.isEmpty ? home : uri.path;
  var decoded = path;
  for (var i = 0; i < 6; i++) {
    if (!decoded.startsWith('/') ||
        decoded.startsWith('//') ||
        _hasForbiddenCharacter(decoded, space: false)) {
      return home;
    }
    final target = Uri(path: decoded).normalizePath().path;
    if (target == _signInPath || target.startsWith('$_signInPath/')) {
      return home;
    }
    final next = _decode(decoded);
    if (next == null) {
      return home;
    }
    if (next == decoded) {
      break;
    }
    decoded = next;
  }
  return '$path'
      '${uri.hasQuery ? '?${uri.query}' : ''}'
      '${uri.hasFragment ? '#${uri.fragment}' : ''}';
}

const String _signInPath = '/auth/sign-in';

/// [text] with every percent escape decoded (`%2F` too), or null when it has
/// a malformed one.
String? _decode(String text) {
  try {
    return Uri.decodeComponent(text);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

/// A backslash (a browser reads `/\evil` as `//evil`), a control character,
/// or, when [space] is set, a space. A link as written has no space (it would
/// be `%20`), but one decoded from `%20` may.
bool _hasForbiddenCharacter(String text, {required bool space}) {
  for (final unit in text.codeUnits) {
    if (unit < 0x20 ||
        (space && unit == 0x20) ||
        unit == 0x7f ||
        unit == 0x5c) {
      return true;
    }
  }
  return false;
}

/// Ticks on a sign-out, not on a sign-in. A sign-in needs no re-evaluation (the
/// sign-in page leaves by itself, with a pop or a `go(from)`), and a refresh
/// that starts with it restores the stack as it was when it started: a pop
/// that follows within the same few frames would be undone and the sign-in
/// page would come back. It subscribes to the session while it has a listener
/// (the router's), so nothing is left running with no router.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(this._session, {required this.onSignedOut});

  final SessionReader _session;

  /// Called after the listeners were told of a sign-out.
  final VoidCallback onSignedOut;
  StreamSubscription<AuthStatus>? _subscription;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _subscription ??= _session.authState.listen((status) {
      if (status == AuthStatus.signedOut) {
        notifyListeners();
        onSignedOut();
      }
    });
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      unawaited(_subscription?.cancel());
      _subscription = null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
