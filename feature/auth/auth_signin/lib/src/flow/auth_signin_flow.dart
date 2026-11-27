import 'package:auth_signin/src/di/di_initializer.dart';
import 'package:auth_signin/src/di/flow_scope.dart';
import 'package:auth_signin/src/domain/model/demo_account.dart';
import 'package:auth_signin/src/domain/model/sign_in_reason.dart';
import 'package:auth_signin/src/domain/model/sign_in_result.dart';
import 'package:auth_signin/src/flow/auth_signin_flow_state.dart';
import 'package:auth_signin/src/l10n/auth_signin_l10n.dart';
import 'package:auth_signin/src/navigator/auth_signin_navigator.dart';
import 'package:auth_signin/src/presentation/page/sign_in_page.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// The feature's only entry point (R4): the sign-in form, which **ends with a
/// result**.
///
/// - When the user signs in, [onComplete] is called once with
///   [SignInResult.signedIn] (the session has started).
/// - When the user taps "Not now", it is called once with
///   [SignInResult.cancelled].
/// - When the user leaves by Back, the app's route is popped and [onComplete]
///   is not called; the route's own pop gives its caller null.
///
/// The app builds it from a route (`/auth/sign-in`, account_wiring) whose
/// [onComplete] hands the result to whoever pushed the route, or goes on to
/// the link the guard sent the user from. Tests pass a recorder. It starts
/// from its arguments alone (plan 01 §4.4).
///
/// Immutable after creation: the flow reads [reason] and [demoAccounts] once,
/// when its scope opens.
class AuthSignInFlow extends StatelessWidget {
  const AuthSignInFlow({
    required this.navigator,
    required this.onComplete,
    this.reason,
    this.demoAccounts = const [],
    super.key,
  });

  final AuthSignInNavigator navigator;

  /// What the user is signing in for; null says nothing.
  final SignInReason? reason;

  /// The accounts "Use a demo account" offers; none hides the helper.
  final List<DemoAccount> demoAccounts;

  /// The flow's result. Called at most once.
  final ValueChanged<SignInResult> onComplete;

  @override
  Widget build(BuildContext context) => FeatureFlow<AuthSignInFlowState>(
    flowInitializer: const AuthSignInDIInitializer(),
    rootImports: authSignInRootImports,
    provide: (scope) => scope.registerSingleton<AuthSignInNavigator>(navigator),
    localizationsDelegates: const [AuthSignInL10n.delegate],
    state: AuthSignInFlowState(reason: reason, demoAccounts: demoAccounts),
    onComplete: (result) => onComplete(result! as SignInResult),
    onGeneratePages: (state) => [
      McFlowPage(
        name: 'auth_sign_in',
        child: SignInPage(
          reason: state.reason,
          demoAccounts: state.demoAccounts,
        ),
      ),
    ],
  );
}
