import 'package:app_core/src/router/router_ref.dart';
import 'package:flutter/material.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';

/// Keys of the sheet, for tests and the e2e journeys.
const fixtureSignInSheetKey = Key('app.sign_in.sheet');
const fixtureSignInButtonKey = Key('app.sign_in.confirm');
const fixtureSignInCancelKey = Key('app.sign_in.cancel');
const fixtureSignInDragGuardKey = Key('app.sign_in.drag_guard');

/// TEMPORARY (P-044): the app's answer to a feature's `requestSignIn()`
/// until a real sign-in feature exists, for every wiring whose navigator
/// needs one (publishing for the favourite, T-0041; library for the reading
/// lists, T-0048).
///
/// True at once when someone is signed in. Otherwise it shows the fixture
/// sign-in sheet on the router's navigator and answers what the sheet
/// answers. False when there is no navigator to show it on yet. [reason]
/// says what signing in is for ("to keep your favourites").
Future<bool> requestFixtureSignIn({
  required RouterRef routerRef,
  required SessionReader session,
  required AuthApi auth,
  required String reason,
}) async {
  if (session.isSignedIn) {
    return true;
  }
  final context = routerRef.router.routerDelegate.navigatorKey.currentContext;
  if (context == null) {
    return false;
  }
  return showFixtureSignInSheet(context, auth, reason: reason);
}

/// A bottom sheet that signs the first fixture user in through `mc_api_auth`
/// (so `mc_session` holds a real session) and pops `true`, or pops `false`
/// when the user backs out.
///
/// It lives in the app layer, never in a feature: features only ask the app
/// to sign in. Its copy is English only, as befits a stand-in.
///
/// The answer is the real outcome however the sheet closes: while a sign-in
/// is under way the sheet refuses a back gesture, a barrier tap (`PopScope`)
/// and a drag down (its content claims vertical drags), and if it is closed
/// anyway (a route change), the sign-in that is already running decides, so
/// a user who ends up signed in is never reported as having backed out.
Future<bool> showFixtureSignInSheet(
  BuildContext context,
  AuthApi auth, {
  required String reason,
}) async {
  final attempt = FixtureSignInAttempt();
  final answer = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) =>
        FixtureSignInSheet(auth: auth, attempt: attempt, reason: reason),
  );
  return answer ?? await (attempt.inFlight ?? Future.value(false));
}

/// The sign-in a sheet started, if any: what decides when the sheet closes
/// without an answer.
final class FixtureSignInAttempt {
  /// True when the sign-in succeeded; null until the user taps Sign in.
  Future<bool>? inFlight;
}

/// The sheet's content: who signs in and why, and Sign in / Not now.
class FixtureSignInSheet extends StatefulWidget {
  const FixtureSignInSheet({
    required this.auth,
    required this.attempt,
    required this.reason,
    super.key,
  });

  final AuthApi auth;

  /// Where the sheet records the sign-in it starts.
  final FixtureSignInAttempt attempt;

  /// What signing in is for, completing "Sign in as … ".
  final String reason;

  /// The account the sheet signs in.
  static FixtureUser get user => fixtureUsers.first;

  @override
  State<FixtureSignInSheet> createState() => _FixtureSignInSheetState();
}

class _FixtureSignInSheetState extends State<FixtureSignInSheet> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final user = FixtureSignInSheet.user;
    final signedIn = widget.auth
        .signIn(email: user.email, password: user.password)
        .then((result) => result.getOrNull() != null);
    widget.attempt.inFlight = signedIn;
    final ok = await signedIn;
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = FixtureSignInSheet.user;
    // No back gesture, barrier tap or drag down while signing in. The
    // bottom sheet's own drag recogniser sits above this content; claiming
    // vertical drags here wins the gesture arena, so the sheet stays put.
    return PopScope(
      canPop: !_busy,
      child: GestureDetector(
        key: fixtureSignInDragGuardKey,
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _busy ? (_) {} : null,
        child: SafeArea(
          key: fixtureSignInSheetKey,
          child: Padding(
            padding: McInsets.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sign in', style: text.titleLarge),
                const McGap.sm(),
                Text(
                  'Sign in as ${user.displayName} (${user.email}) '
                  '${widget.reason}.',
                  style: text.bodyLarge,
                ),
                if (_failed) ...[
                  const McGap.sm(),
                  Text(
                    'Signing in failed. Please try again.',
                    style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const McGap.lg(),
                McButton(
                  key: fixtureSignInButtonKey,
                  label: 'Sign in',
                  expand: true,
                  onPressed: _busy ? null : _signIn,
                ),
                const McGap.sm(),
                McButton(
                  key: fixtureSignInCancelKey,
                  label: 'Not now',
                  variant: McButtonVariant.tertiary,
                  expand: true,
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
