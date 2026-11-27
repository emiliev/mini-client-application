import 'package:auth_signin/src/domain/model/demo_account.dart';
import 'package:auth_signin/src/domain/model/sign_in_reason.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_signin_flow_state.freezed.dart';

/// The flow's arguments, which the flow starts from (plan 01 §4.4). The form
/// has one page, so nothing changes while it is open; the form's values live
/// in the bloc's form controller.
@freezed
abstract class AuthSignInFlowState with _$AuthSignInFlowState {
  const factory AuthSignInFlowState({
    /// What the user is signing in for; null says nothing.
    SignInReason? reason,

    /// The accounts "Use a demo account" offers; none hides the helper.
    @Default(<DemoAccount>[]) List<DemoAccount> demoAccounts,
  }) = _AuthSignInFlowState;
}
