// T-0066-AC2: the sign-in guard's pure logic: which locations are protected,
// where a signed-out user is sent, and (the security core) which `from` the
// sign-in screen may go to afterwards. Plain unit tests (ADR-0015): a table
// of exact values, so a changed rule shows as a changed row.
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_session/mc_session.dart';

/// A session that is signed in or out, and announces each change.
final class _FakeSession implements SessionReader {
  _FakeSession({bool signedIn = false}) : _signedIn = signedIn;

  bool _signedIn;
  final StreamController<AuthStatus> changes =
      StreamController<AuthStatus>.broadcast();

  void signIn() {
    _signedIn = true;
    changes.add(AuthStatus.signedIn);
  }

  void signOut() {
    _signedIn = false;
    changes.add(AuthStatus.signedOut);
  }

  @override
  bool get isSignedIn => _signedIn;

  @override
  AuthStatus get status =>
      _signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;

  @override
  Stream<AuthStatus> get authState => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('T-0066-AC2 which locations are protected', () {
    const protected = [
      '/me',
      '/me/lists/new',
      '/me/lists/l-1/edit',
      '/library',
      '/library/shelf',
      '/store/checkout',
      '/store/checkout/pay',
      // A link in the running app carries its scheme and host.
      'miniclient://app/me/lists/new',
      'miniclient://app/store/checkout?coupon=x',
      // Another case, an encoding, a `..` or a double encoding is no way
      // round the guard.
      '/ME/lists/new',
      '/%6De/lists/new',
      '/me%2Flists',
      '/x/../me/lists/new',
      '/x/%2E%2E/me/lists/new',
      '/%256De/lists/new',
      '/store/Checkout',
    ];
    const open = [
      '/',
      '/menu',
      '/me-too',
      '/characters',
      '/comics/501500',
      '/search?q=me',
      '/store',
      '/store/categories/c-1',
      '/store/checkout-help',
      '/libraryx',
      '/settings',
      '/settings/appearance',
      '/auth/sign-in',
      '/auth/sign-in?from=%2Fme%2Flists%2Fnew',
      '/not-found?from=%2Fme',
    ];

    for (final location in protected) {
      test('T-0066-AC2 $location is protected', () {
        expect(SignInGuard.isProtectedLocation(Uri.parse(location)), isTrue);
      });
    }
    for (final location in open) {
      test('T-0066-AC2 $location is open', () {
        expect(SignInGuard.isProtectedLocation(Uri.parse(location)), isFalse);
      });
    }
  });

  group('T-0066-AC2 where the guard sends a signed-out user', () {
    test('T-0066-AC2 a protected location goes to sign-in with from set', () {
      final guard = SignInGuard(_FakeSession());

      expect(
        guard.redirect(Uri.parse('/me/lists/new')),
        '/auth/sign-in?from=%2Fme%2Flists%2Fnew',
      );
      expect(
        guard.redirect(Uri.parse('/library/shelf?tab=2#top')),
        '/auth/sign-in?from=%2Flibrary%2Fshelf%3Ftab%3D2%23top',
      );
      expect(
        guard.redirect(Uri.parse('/store/checkout')),
        '/auth/sign-in?from=%2Fstore%2Fcheckout',
      );
    });

    test('T-0066-AC2 a link in the running app is sent as its path, with '
        'no scheme or host', () {
      final guard = SignInGuard(_FakeSession());

      expect(
        guard.redirect(Uri.parse('miniclient://app/me/lists/new?x=1')),
        '/auth/sign-in?from=%2Fme%2Flists%2Fnew%3Fx%3D1',
      );
    });

    test(
      'T-0066-AC2 an encoded path is kept as written, not encoded again',
      () {
        final guard = SignInGuard(_FakeSession());

        expect(
          guard.redirect(Uri.parse('/me/lists/a%2Fb/edit')),
          '/auth/sign-in?from=%2Fme%2Flists%2Fa%252Fb%2Fedit',
        );
        expect(
          Uri.parse(
            guard.redirect(Uri.parse('/me/lists/a%2Fb/edit'))!,
          ).queryParameters['from'],
          '/me/lists/a%2Fb/edit',
        );
      },
    );

    test('T-0066-AC2 an open location is never redirected', () {
      final guard = SignInGuard(_FakeSession());

      for (final location in ['/', '/characters', '/store', '/auth/sign-in']) {
        expect(guard.redirect(Uri.parse(location)), isNull, reason: location);
      }
    });

    test('T-0066-AC2 a signed-in user is never redirected', () {
      final guard = SignInGuard(_FakeSession(signedIn: true));

      for (final location in [
        '/me/lists/new',
        '/library/shelf',
        '/store/checkout',
        'miniclient://app/me/lists/l-1/edit',
        '/%6De/lists/new',
      ]) {
        expect(guard.redirect(Uri.parse(location)), isNull, reason: location);
      }
    });

    test('T-0066-AC2 a signed-in user at the sign-in page is sent on to its '
        'safe from, else home', () {
      final guard = SignInGuard(_FakeSession(signedIn: true));

      expect(
        guard.redirect(Uri.parse('/auth/sign-in?from=%2Fme%2Flists%2Fnew')),
        '/me/lists/new',
      );
      expect(guard.redirect(Uri.parse('/auth/sign-in')), '/');
      expect(
        guard.redirect(Uri.parse('/auth/sign-in?from=https%3A%2F%2Fevil.com')),
        '/',
      );
      expect(
        guard.redirect(Uri.parse('/auth/sign-in?from=%2Fauth%2Fsign-in')),
        '/',
      );
      expect(
        guard.redirect(Uri.parse('/x/../auth/sign-in?from=%2Fme%2Fa')),
        '/me/a',
      );
    });

    test('T-0066-AC2 the guard reads the session at every call', () {
      final session = _FakeSession();
      final guard = SignInGuard(session);
      final uri = Uri.parse('/me/lists/new');

      expect(guard.redirect(uri), isNotNull);
      session.signIn();
      expect(guard.redirect(uri), isNull);
      session.signOut();
      expect(guard.redirect(uri), isNotNull);
    });
  });

  group(
    'T-0066-AC2 the sign-in screen goes only to a location of this app',
    () {
      /// Each row: what `from` says, where the screen goes.
      const goes = {
        '/me/lists/new': '/me/lists/new',
        '/me/lists/l-1/edit': '/me/lists/l-1/edit',
        '/me/lists/new?x=1&y=2#top': '/me/lists/new?x=1&y=2#top',
        '/store/checkout': '/store/checkout',
        '/': '/',
        '/characters/100000': '/characters/100000',
        // A path is kept as written, an encoded segment included.
        '/me/lists/a%20b/edit': '/me/lists/a%20b/edit',
        '/me/lists/a%2Fb/edit': '/me/lists/a%2Fb/edit',
        // The app's own link form loses its scheme and host.
        'miniclient://app/me/lists/new': '/me/lists/new',
        'miniclient://app/me/lists/new?x=1#f': '/me/lists/new?x=1#f',
        'miniclient://app': '/',
        'miniclient://app/': '/',
        'MINICLIENT://APP/me/lists/new': '/me/lists/new',
      };

      for (final entry in goes.entries) {
        test('T-0066-AC2 ${entry.key} goes to ${entry.value}', () {
          expect(safeSignInTarget(entry.key), entry.value);
        });
      }

      /// Everything here must fall back to home: foreign schemes, hosts,
      /// scheme-relative and relative references, backslashes, control
      /// characters, user-info and ports, the sign-in screen itself, and every
      /// one of them percent-encoded once or more.
      const hostile = [
        // Foreign schemes and hosts.
        'https://evil.com',
        'https://evil.com/me/lists/new',
        'http://evil.com',
        'HTTPS://EVIL.COM',
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'tel:+15550100',
        'mailto:a@b.c',
        'mini-client://app/me',
        'miniclient2://app/me',
        'miniclient://evil.com/me/lists/new',
        'miniclient://app.evil.com/me',
        'miniclient://evil.com/app',
        // The app's scheme with something else in its authority.
        'miniclient://user@app/me',
        'miniclient://app@evil.com/me',
        'miniclient://app:8080/me',
        'miniclient://app:evil.com/me',
        // Scheme-relative and malformed absolute forms.
        '//evil.com',
        '//evil.com/me/lists/new',
        '///evil.com',
        '////evil.com',
        '/\\evil.com',
        '\\\\evil.com',
        '\\/evil.com',
        '/me\\..\\evil',
        // Relative references.
        'evil.com',
        'me/lists/new',
        '../me/lists/new',
        '?from=/me',
        '#/me',
        // Whitespace and control characters, raw and encoded.
        ' /me/lists/new',
        '/me/lists/new ',
        '/me/lists/new\n',
        '/me/\tlists',
        '\t//evil.com',
        '/%0Ame',
        '/%0D%0ALocation:%20https://evil.com',
        '/%00',
        '/%09/evil',
        '/%7F',
        // Encoded `//`, `\` and scheme-relative forms, once and twice.
        '%2F%2Fevil.com',
        '/%2Fevil.com',
        '/%2fevil.com',
        '/%252Fevil.com',
        '/%25252Fevil.com',
        '/%5Cevil.com',
        '/%5cevil.com',
        '/%255Cevil.com',
        '%5C%5Cevil.com',
        '/%2F%2Fevil.com',
        // Malformed encodings.
        '/%',
        '/%E0%A4%A',
        '/%zz',
        '/me/%',
        // The sign-in screen itself would loop.
        '/auth/sign-in',
        '/auth/sign-in?from=/me/lists/new',
        '/auth/sign-in/',
        '/auth/sign-in#x',
        '/x/../auth/sign-in',
        '/auth%2Fsign-in',
        '/auth/%73ign-in',
        '/%2561uth/sign-in',
        'miniclient://app/auth/sign-in?from=/me',
        // Nothing at all.
        '',
      ];

      for (final from in hostile) {
        test('T-0066-AC2 ${from.isEmpty ? '(empty)' : from} falls back to '
            'home', () {
          expect(safeSignInTarget(from), AppLocations.home);
        });
      }

      test('T-0066-AC2 no from goes home', () {
        expect(safeSignInTarget(null), AppLocations.home);
      });

      test('T-0066-AC2 whatever it is given, the answer is a location of this '
          'app: one slash, no scheme, no backslash', () {
        for (final from in [...hostile, ...goes.keys]) {
          final target = safeSignInTarget(from);
          expect(target, startsWith('/'), reason: from);
          expect(target, isNot(startsWith('//')), reason: from);
          expect(target, isNot(contains('\\')), reason: from);
          expect(Uri.parse(target).hasScheme, isFalse, reason: from);
          expect(Uri.parse(target).hasAuthority, isFalse, reason: from);
        }
      });

      test('T-0066-AC2 the location the guard builds comes back unchanged '
          'through the sign-in link', () {
        for (final original in [
          '/me/lists/new',
          '/me/lists/l-1/edit',
          '/me/lists/a%2Fb/edit?x=1&y=%26#top',
          '/library/shelf?tab=2',
          '/store/checkout',
        ]) {
          final link = AppLocations.signIn(from: original);
          final from = Uri.parse(link).queryParameters['from'];
          expect(from, original);
          expect(safeSignInTarget(from), original);
        }
      });
    },
  );

  group('T-0066-AC2 the router refresh follows the session', () {
    test('T-0066-AC2 it listens to the session only while the router listens '
        'to it', () async {
      final session = _FakeSession();
      final guard = SignInGuard(session);
      expect(session.changes.hasListener, isFalse, reason: 'nobody yet');

      var ticks = 0;
      void tick() => ticks++;
      guard.refresh.addListener(tick);
      expect(session.changes.hasListener, isTrue);

      session.signIn();
      await Future<void>.delayed(Duration.zero);
      expect(ticks, 0, reason: 'a sign-in needs no re-evaluation');
      session.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(ticks, 1, reason: 'a sign-out does');

      guard.refresh.removeListener(tick);
      expect(session.changes.hasListener, isFalse, reason: 'the last one left');
      session.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(ticks, 1, reason: 'nobody listens: no tick');

      await session.changes.close();
    });

    test('T-0066-AC2 two listeners share one subscription, which ends with '
        'the last', () async {
      final session = _FakeSession();
      final guard = SignInGuard(session);
      final seen = <String>[];
      void a() => seen.add('a');
      void b() => seen.add('b');

      guard.refresh
        ..addListener(a)
        ..addListener(b);
      session.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['a', 'b']);

      guard.refresh.removeListener(a);
      expect(session.changes.hasListener, isTrue, reason: 'b still listens');
      session
        ..signIn()
        ..signOut();
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['a', 'b', 'b']);

      guard.refresh.removeListener(b);
      expect(session.changes.hasListener, isFalse);
      await session.changes.close();
    });
  });
}
