import 'package:auth_signin/src/domain/model/demo_account.dart';
import 'package:auth_signin/src/domain/model/sign_in_failure.dart';
import 'package:auth_signin/src/domain/model/sign_in_result.dart';
import 'package:auth_signin/src/domain/repository/auth_signin_repository.dart';
import 'package:auth_signin/src/flow/auth_signin_flow_state.dart';
import 'package:auth_signin/src/presentation/form/auth_signin_form.dart';
import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';

part 'auth_signin_event.dart';
part 'auth_signin_state.dart';

/// The sign-in form's bloc: one per flow (a lazy singleton of the flow's own
/// container).
///
/// - **One request per submit:** `FormController.submit` ignores a submit
///   while one runs, and once the sign-in succeeded the bloc ignores every
///   further event but the form's own: a double tap on Sign in sends one
///   request, also in the moment between the answer and the page leaving.
/// - **Typed failures:** the form's failed submit is read as a
///   [SignInFailure] (`InvalidCredentials`, or `SignInUnavailable` with the
///   cause). An edit clears it; submitting again is the retry.
/// - **No leaving mid-request:** "Not now" is ignored while a request runs,
///   and the page has no back button then, so a sign-in that is on its way is
///   never answered as "cancelled". A system back or a link can still close
///   the flow: a sign-in that lands after that is undone (the session ends),
///   so "no result" never means "someone is signed in".
/// - **The result:** a sign-in completes the flow with
///   `SignInResult.signedIn`, "Not now" with `SignInResult.cancelled`
///   (`onComplete` fires once, `FeatureFlowController`).
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter.
@lazySingleton
final class AuthSignInBloc extends McBloc<AuthSignInEvent, AuthSignInState> {
  AuthSignInBloc(
    this._repository,
    this._flow,
    this._session,
    Monitoring monitoring,
  ) : super(
        AuthSignInState(
          FormController(fields: signInFields(), onState: (_) {}).state,
        ),
        monitoring: monitoring,
      ) {
    on<AuthSignInEvent>(_onEvent);
    _form = FormController(
      fields: signInFields(),
      onState: (form) {
        if (!isClosed) {
          add(_FormChanged(form));
        }
      },
    );
    // The state's own form is the throwaway above; the live one replaces it.
    add(_FormChanged(_form.state));
  }

  final AuthSignInRepository _repository;
  final FeatureFlowController<AuthSignInFlowState> _flow;
  final SessionReader _session;
  late final FormController _form;

  /// The sign-in succeeded: nothing but the form's own updates is handled
  /// any more.
  bool _signedIn = false;

  Future<void> _onEvent(
    AuthSignInEvent event,
    Emitter<AuthSignInState> emit,
  ) async {
    if (event is _FormChanged) {
      emit(AuthSignInState(event.form));
      return;
    }
    if (_signedIn) {
      return;
    }
    switch (event) {
      case _FormChanged():
        break;
      case _EmailChanged(:final email):
        _form.setValue(SignInFields.email, email);
      case _PasswordChanged(:final password):
        _form.setValue(SignInFields.password, password);
      case _Touched(:final field):
        _form.touch(field);
      case _UseDemoAccount(:final account):
        _form
          ..setValue(SignInFields.email, account.email)
          ..setValue(SignInFields.password, account.password);
      case _Submit():
        await _submit();
      case _NotNow():
        if (!_form.state.isSubmitting) {
          _flow.complete(SignInResult.cancelled);
        }
    }
  }

  Future<void> _submit() async {
    // Who was signed in when the request was sent, and which session this
    // request creates: leaving mid-request undoes only the latter, and only
    // when nobody was signed in before.
    final signedInBefore = _session.isSignedIn;
    int? createdEpoch;
    final result = await _form.submit<AuthUser>((values) async {
      final answer = await _repository.signIn(
        email: values.get<String>(SignInFields.email) ?? '',
        password: values.get<String>(SignInFields.password) ?? '',
      );
      final user = answer.getOrNull();
      if (user != null && _session.userId == user.id) {
        createdEpoch = _session.epoch;
      }
      return answer;
    });
    if (result == null) {
      // Invalid (the form shows why), or a request is already running (a
      // double tap).
      return;
    }
    if (isClosed) {
      // The flow was closed (a link, a screen replaced) while the request was
      // on its way. The caller was told "no sign-in", so a session this
      // request created is undone (leaving cancels), and only that one,
      // never a newer session. When someone was signed in before the form,
      // that user was already replaced by this sign-in, so the new session
      // stays: the outcome is A or B, never signed out. A system back or an
      // iOS swipe cannot reach here: the page refuses it while a request
      // runs.
      final epoch = createdEpoch;
      if (!signedInBefore && epoch != null) {
        await _repository.signOut(epoch: epoch);
      }
      return;
    }
    result.fold((_) {
      _signedIn = true;
      _flow.complete(SignInResult.signedIn);
    }, (_) {});
  }

  /// The flow's container disposes the bloc with the flow (`@disposeMethod`:
  /// injectable registers nothing to close a bloc otherwise).
  @disposeMethod
  @override
  Future<void> close() {
    _form.dispose();
    return super.close();
  }
}
