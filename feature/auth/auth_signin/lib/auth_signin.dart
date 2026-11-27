// The public surface (R4, checked by mc_arch_check and the architecture
// test): the flow, its navigator, and the flow's argument and result types.
// No `library;` directive (Tide's `unnecessary_library_directive`).
export 'package:auth_signin/src/domain/model/demo_account.dart'
    show DemoAccount;
export 'package:auth_signin/src/domain/model/sign_in_reason.dart'
    show SignInReason;
export 'package:auth_signin/src/domain/model/sign_in_result.dart'
    show SignInResult;
export 'package:auth_signin/src/flow/auth_signin_flow.dart' show AuthSignInFlow;
export 'package:auth_signin/src/navigator/auth_signin_navigator.dart'
    show AuthSignInNavigator;
