import 'package:auth_signin/src/domain/model/demo_account.dart';
import 'package:auth_signin/src/domain/model/sign_in_failure.dart';
import 'package:auth_signin/src/domain/model/sign_in_reason.dart';
import 'package:auth_signin/src/l10n/auth_signin_l10n.dart';
import 'package:auth_signin/src/presentation/bloc/auth_signin_bloc.dart';
import 'package:auth_signin/src/presentation/form/auth_signin_form.dart';
import 'package:auth_signin/src/presentation/widget/messages.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Keys of the form, for tests and the e2e journeys.
const signInFormKey = ValueKey<String>('auth_signin.form');
const signInNotNowKey = ValueKey<String>('auth_signin.not_now');
const signInReasonKey = ValueKey<String>('auth_signin.reason');

/// The key of the "Use a demo account" button for [email].
ValueKey<String> demoAccountKey(String email) =>
    ValueKey<String>('auth_signin.demo.$email');

/// The flow's one page: the sign-in form. The bloc belongs to the flow, so
/// the page provides it with `BlocProvider.value`; the flow's container
/// closes it.
class SignInPage extends StatelessWidget {
  const SignInPage({
    required this.reason,
    required this.demoAccounts,
    super.key,
  });

  final SignInReason? reason;
  final List<DemoAccount> demoAccounts;

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    // The only DI lookup in UI code (R17).
    value: context.di<AuthSignInBloc>(),
    child: _SignInContent(reason: reason, demoAccounts: demoAccounts),
  );
}

class _SignInContent extends StatelessWidget {
  const _SignInContent({required this.reason, required this.demoAccounts});

  final SignInReason? reason;
  final List<DemoAccount> demoAccounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AuthSignInL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    return BlocBuilder<AuthSignInBloc, AuthSignInState>(
      builder: (context, state) {
        final bloc = context.read<AuthSignInBloc>();
        final form = state.form;
        final failure = state.failure;
        final busy = state.isBusy;
        return _OuterPopBlock(
          blocked: busy,
          child: PopScope(
            canPop: !busy,
            child: McFormScaffold(
              appBar: McAppBar(
                // No way out while a request is on its way: its answer must
                // never arrive for a screen that is gone.
                leading: busy
                    ? const SizedBox.shrink()
                    : const McFlowBackButton(),
                title: l10n.authSignInTitle,
              ),
              submitLabel: failure is SignInUnavailable
                  ? l10n.authSignInTryAgain
                  : l10n.authSignInSubmit,
              busyLabel: l10n.authSignInBusy,
              // The spinner is for the request only: after the sign-in the page
              // is about to leave and merely stays disabled.
              isSubmitting: form.isSubmitting,
              onSubmit: busy
                  ? null
                  : () => bloc.add(const AuthSignInEvent.submit()),
              errorText: failure == null
                  ? null
                  : signInFailureMessage(failure, l10n, core),
              body: Column(
                key: signInFormKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reasonMessage(reason, l10n),
                    key: signInReasonKey,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const McGap.lg(),
                  McFormTextField(
                    field: form.fieldOf<String>(SignInFields.email),
                    label: l10n.authSignInEmailLabel,
                    onChanged: (v) => bloc.add(AuthSignInEvent.emailChanged(v)),
                    onTouched: () => bloc.add(
                      const AuthSignInEvent.touched(SignInFields.email),
                    ),
                    errorMessage: (e) =>
                        fieldErrorMessage(SignInFields.email, e, l10n),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const McGap.md(),
                  McFormTextField(
                    field: form.fieldOf<String>(SignInFields.password),
                    label: l10n.authSignInPasswordLabel,
                    onChanged: (v) =>
                        bloc.add(AuthSignInEvent.passwordChanged(v)),
                    onTouched: () => bloc.add(
                      const AuthSignInEvent.touched(SignInFields.password),
                    ),
                    errorMessage: (e) =>
                        fieldErrorMessage(SignInFields.password, e, l10n),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                  if (demoAccounts.isNotEmpty) ...[
                    const McGap.xl(),
                    McFieldGroup(
                      title: l10n.authSignInDemoTitle,
                      description: l10n.authSignInDemoHint,
                      children: [
                        for (final account in demoAccounts)
                          McButton(
                            key: demoAccountKey(account.email),
                            label: l10n.authSignInDemoAccount(
                              account.displayName,
                              account.email,
                            ),
                            variant: McButtonVariant.secondary,
                            expand: true,
                            onPressed: busy
                                ? null
                                : () => bloc.add(
                                    AuthSignInEvent.useDemoAccount(account),
                                  ),
                          ),
                      ],
                    ),
                  ],
                  const McGap.lg(),
                  McButton(
                    key: signInNotNowKey,
                    label: l10n.authSignInNotNow,
                    variant: McButtonVariant.tertiary,
                    expand: true,
                    onPressed: busy
                        ? null
                        : () => bloc.add(const AuthSignInEvent.notNow()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps the flow's own route (the one in the app's navigator) from popping
/// while [blocked]: a system back, an iOS swipe and the outer back button all
/// ask that route. A `PopScope` inside the flow only guards the flow's inner
/// page, so this registers a pop entry with [FlowScope.outerRoute] too (what
/// the removed sheet's `PopScope` guaranteed: a sign-in under way is never
/// silently cut off, and the swipe gesture is disabled with it).
class _OuterPopBlock extends StatefulWidget {
  const _OuterPopBlock({required this.blocked, required this.child});

  final bool blocked;
  final Widget child;

  @override
  State<_OuterPopBlock> createState() => _OuterPopBlockState();
}

class _OuterPopBlockState extends State<_OuterPopBlock>
    implements PopEntry<Object?> {
  late final ValueNotifier<bool> _canPop = ValueNotifier<bool>(
    !widget.blocked,
  );
  ModalRoute<Object?>? _route;

  @override
  ValueListenable<bool> get canPopNotifier => _canPop;

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = FlowScope.maybeOf(context)?.outerRoute;
    if (!identical(route, _route)) {
      _route?.unregisterPopEntry(this);
      _route = route?..registerPopEntry(this);
    }
  }

  @override
  void didUpdateWidget(_OuterPopBlock old) {
    super.didUpdateWidget(old);
    _canPop.value = !widget.blocked;
  }

  @override
  void dispose() {
    _route?.unregisterPopEntry(this);
    _canPop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
