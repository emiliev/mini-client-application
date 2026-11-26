import 'package:flutter/material.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';

/// Keys of the sheet, for tests and the e2e journey.
const fixtureSignInSheetKey = Key('publishing.sign_in.sheet');
const fixtureSignInButtonKey = Key('publishing.sign_in.confirm');
const fixtureSignInCancelKey = Key('publishing.sign_in.cancel');

/// TEMPORARY (P-044): the app's answer to a feature's `requestSignIn()`
/// until a real sign-in feature exists. A bottom sheet that signs the first
/// fixture user in through `mc_api_auth` (so `mc_session` holds a real
/// session) and pops `true`, or pops `false` when the user backs out.
///
/// It lives in the wiring, never in a feature: features only ask the app to
/// sign in. Its copy is English only, as befits a stand-in.
Future<bool> showFixtureSignInSheet(BuildContext context, AuthApi auth) async {
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => FixtureSignInSheet(auth: auth),
  );
  return signedIn ?? false;
}

/// The sheet's content: who signs in, and Sign in / Not now.
class FixtureSignInSheet extends StatefulWidget {
  const FixtureSignInSheet({required this.auth, super.key});

  final AuthApi auth;

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
    final result = await widget.auth.signIn(
      email: user.email,
      password: user.password,
    );
    if (!mounted) {
      return;
    }
    if (result.getOrNull() != null) {
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
    return SafeArea(
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
              'Sign in as ${user.displayName} (${user.email}) to keep your '
              'favourites.',
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
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
