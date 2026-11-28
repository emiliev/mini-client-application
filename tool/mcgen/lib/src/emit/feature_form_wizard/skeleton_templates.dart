// The skeleton's lib/ templates: the first writes of a new module's own
// files (owned from then on). Raw text with `<<name>>` placeholders, so
// Dart's own `$` needs no escaping. The shape is the exemplars' (F-0048,
// F-0066): one `WizardController` over all steps (a form is a wizard of one),
// the bloc's guards, `authPinned` writes and the session-epoch rule.

const resultIdTemplate = r'''
extension type const <<Result>>(String value) {}''';

const repositoryTemplate = r'''
/// The server's answer to a write as a value, never an exception. Stateless
/// (Tide): what the form shows lives in the bloc and the flow state.
///
/// A write the backend refuses is an `ApiClientError` whose `code` and
/// `parameter` come from the error body (`mc_api_errors`), so the form can
/// show it under the field it names.
@injectable
class <<Repository>> {
  const <<Repository>>(this._dio);

  final Dio _dio;

  /// Sends [body] and answers the new item's id.
  ///
  /// Every write is pinned to the session [epoch] the caller checked
  /// (T-0050): if the session changed before the request was sent, nothing
  /// is sent and the answer is `ApiUnauthorized`, so nothing is written
  /// under another user's bearer.
  Future<Result<<<Result>>, ApiFailure>> create(
    Map<String, Object?> body, {
    required int epoch,
  }) => apiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '<<path>>',
      data: body,
      options: Options(extra: authPinned(epoch)),
    );
    return <<Result>>(response.data!['<<idKey>>'] as String);
  });
}''';

const formTemplate = r'''
/// The wizard's field names (one form over all steps, `mc_forms`).
abstract final class <<Pascal>>Fields {
<<field_consts>>

  /// The form field a `400`'s `parameter` names, or null for one the user
  /// cannot change.
  static String? ofParameter(String? parameter) => switch (parameter) {
<<of_parameter>>    _ => null,
  };
}

/// The step ids, in order.
abstract final class <<Pascal>>Steps {
<<step_consts>>
}

/// What the form shows under a field the backend refused (its `error.code`):
/// "this value was not accepted".
FieldError serverError(String? code) =>
    const FieldError(ValidationCode.invalid);

<<trimmed_fn>>/// The steps over one form. A step without fields is the review.
List<WizardStep> <<camel>>Steps() => [
<<steps>>];

/// The wizard's values as the request body.
Map<String, Object?> <<camel>>BodyOf(FormValues values) => {
<<body>>};''';

const eventTemplate = r'''
/// What the step pages ask for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories.
sealed class <<Pascal>>Event {
  const <<Pascal>>Event();

  /// A field's value changed.
  const factory <<Pascal>>Event.fieldChanged(String field, String value) =
      _FieldChanged;

  /// A text field lost focus: its error may show.
  const factory <<Pascal>>Event.touched(String field) = _Touched;

  /// Next, when the step is valid.
  const factory <<Pascal>>Event.next() = _Next;

  /// A disabled Next was tapped: the step's errors show.
  const factory <<Pascal>>Event.blockedNext() = _BlockedNext;

  /// Back to the step before.
  const factory <<Pascal>>Event.back() = _Back;

  /// The last step's button: send the values.
  const factory <<Pascal>>Event.submit() = _Submit;

  /// Close the form after its session ended.
  const factory <<Pascal>>Event.close() = _Close;
}

final class _FieldChanged extends <<Pascal>>Event {
  const _FieldChanged(this.field, this.value);

  final String field;
  final String value;
}

final class _Touched extends <<Pascal>>Event {
  const _Touched(this.field);

  final String field;
}

final class _Next extends <<Pascal>>Event {
  const _Next();
}

final class _BlockedNext extends <<Pascal>>Event {
  const _BlockedNext();
}

final class _Back extends <<Pascal>>Event {
  const _Back();
}

final class _Submit extends <<Pascal>>Event {
  const _Submit();
}

final class _Close extends <<Pascal>>Event {
  const _Close();
}

/// Internal: the form opens (the session is looked at once, in a handler).
final class _Start extends <<Pascal>>Event {
  const _Start();
}

/// Internal: the wizard controller reported a new state (outside any
/// handler; an event brings it back into the bloc, so only a handler emits).
final class _WizardChanged extends <<Pascal>>Event {
  const _WizardChanged(this.wizard);

  final WizardState<<<Result>>> wizard;
}

/// Internal: the session changed (a sign-out, or another user signed in).
final class _SessionChanged extends <<Pascal>>Event {
  const _SessionChanged();
}''';

const stateTemplate = r'''
/// What the step pages show.
sealed class <<Pascal>>State {
  const <<Pascal>>State();
}

/// Opening: the session is not looked at yet.
final class <<Pascal>>Opening extends <<Pascal>>State {
  const <<Pascal>>Opening();
}

/// The wizard: every step's values, the current step and the save's status.
final class <<Pascal>>Editing extends <<Pascal>>State {
  const <<Pascal>>Editing(this.wizard);

  final WizardState<<<Result>>> wizard;
}

/// The session the form belongs to ended (a sign-out, or another user signed
/// in). Nothing more is written; the user can only close the form.
final class <<Pascal>>SessionEnded extends <<Pascal>>State {
  const <<Pascal>>SessionEnded();
}''';

const blocTemplate = r'''
/// What a save returns when it stops before a write: the session it was
/// started for has ended (the bloc then shows the session-ended state,
/// whatever the save answered), or the form was closed.
const ApiFailure _stopped = ApiFailure.unauthorized(
  'The session changed or the form closed',
);

/// The form's bloc: one per flow (a lazy singleton of the flow's own
/// container), shared by the step pages, so the wizard's values outlive any
/// one page (going back keeps every step's values).
///
/// - **The wizard:** `mc_forms`' `WizardController`, one form over all
///   steps. Its step is mirrored in the flow state, so each step is a page
///   and a back gesture is a step back; a pop the flow reports is applied to
///   the wizard.
/// - **One save at a time:** the wizard runs one completion, so a double tap
///   on the last step's button sends one request.
/// - **The session decides:** the form belongs to the session it opened for.
///   After every await before a write the epoch is compared again (F-0040
///   fact 21), the write is pinned with `authPinned(epoch)`, and a result
///   that arrives for an ended session is not handed out: the form shows the
///   session-ended state and writes nothing more.
/// - **The result:** a saved item completes the flow with its id.
/// - **The backend's verdicts:** a `400` naming a field goes to that field's
///   step and shows the error under it (`WizardController.reject`).
/// - **Closed means stopped:** after every await it returns if the bloc was
///   closed (the user left while a save was in flight), so nothing is
///   emitted or written for a flow that is gone.
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter.
@lazySingleton
final class <<Pascal>>Bloc extends McBloc<<<Pascal>>Event, <<Pascal>>State> {
  <<Pascal>>Bloc(
    this._repository,
    this._flow,
    this._session,
    Monitoring monitoring,
  ) : super(const <<Pascal>>Opening(), monitoring: monitoring) {
    on<<<Pascal>>Event>(_onEvent);
    _flowChanges = _flow.states.listen(_onFlowState);
    _sessionChanges = _session.authState.listen((_) {
      if (!isClosed) {
        add(const _SessionChanged());
      }
    });
    add(const _Start());
  }

  final <<Pascal>>Repository _repository;
  final FeatureFlowController<<<Pascal>>FlowState> _flow;
  final SessionReader _session;
  late final StreamSubscription<<<Pascal>>FlowState> _flowChanges;
  late final StreamSubscription<AuthStatus> _sessionChanges;

  /// Null until the form has a signed-in session, and again once that
  /// session ended.
  WizardController<<<Result>>>? _wizard;

  /// The session epoch the form belongs to; null until it has one.
  int? _epoch;

  bool _ended = false;

  Future<void> _onEvent(
    <<Pascal>>Event event,
    Emitter<<<Pascal>>State> emit,
  ) async {
    final wizard = _wizard;
    switch (event) {
      case _Start():
        _start();
      case _WizardChanged(:final wizard):
        if (_wizard != null) {
          emit(<<Pascal>>Editing(wizard));
        }
      case _FieldChanged(:final field, :final value):
        wizard?.setValue(field, value);
      case _Touched(:final field):
        wizard?.touch(field);
      case _Next():
        wizard?.next();
      case _BlockedNext():
        wizard?.touchCurrentStep();
      case _Back():
        wizard?.back();
      case _Submit():
        if (wizard != null) {
          await _submit(wizard, emit);
        }
      case _Close():
        _flow.complete();
      case _SessionChanged():
        _onSessionChanged(emit);
    }
  }

  /// The form needs a signed-in session: without one the flow ends with no
  /// result. The app signs the user in before it opens a flow that needs it.
  void _start() {
    if (!_session.isSignedIn) {
      _flow.complete();
      return;
    }
    _epoch = _session.epoch;
    final wizard = WizardController<<<Result>>>(
      steps: <<camel>>Steps(),
      onState: _onWizardState,
      onComplete: _save,
    );
    _wizard = wizard;
    add(_WizardChanged(wizard.state));
  }

  /// The wizard's step is the flow's: a step change opens or closes step
  /// pages. Then the state comes back into the bloc as an event.
  void _onWizardState(WizardState<<<Result>>> wizard) {
    if (_flow.state.step != wizard.stepIndex) {
      _flow.update((s) => s.copyWith(step: wizard.stepIndex));
    }
    if (!isClosed) {
      add(_WizardChanged(wizard));
    }
  }

  /// A step page was popped (a back gesture, the app bar's back): the
  /// wizard goes back with it, keeping every value. While a save runs the
  /// last page refuses the pop, so the two never disagree.
  void _onFlowState(<<Pascal>>FlowState flow) {
    final wizard = _wizard;
    if (wizard == null) {
      return;
    }
    while (flow.step < wizard.state.stepIndex && wizard.back()) {}
  }

  Future<void> _submit(
    WizardController<<<Result>>> wizard,
    Emitter<<<Pascal>>State> emit,
  ) async {
    final outcome = await wizard.complete();
    if (outcome == null) {
      // Invalid (the wizard shows the first invalid step), or a save is
      // already running: a double tap sends one request.
      return;
    }
    if (isClosed) {
      return;
    }
    if (_session.epoch != _epoch) {
      // Whatever the save answered, it belongs to a session that is gone.
      _end(emit);
      return;
    }
    outcome.fold(_flow.complete, (error) {
      // A `400` naming a field the user can change: show it there.
      if (error case ApiClientError(
        status: 400,
        :final code,
        :final parameter,
      )) {
        final field = <<Pascal>>Fields.ofParameter(parameter);
        if (field != null) {
          wizard.reject(field, serverError(code));
        }
      }
    });
  }

  /// The wizard's completion: one write, sent only while the form's session
  /// is current and the form is open (checked after the await in `_submit`
  /// too).
  Future<Result<<<Result>>, ApiFailure>> _save(FormValues values) async {
    final epoch = _epoch;
    if (epoch == null || !_canWrite(epoch)) {
      return failure(_stopped);
    }
    return _repository.create(<<camel>>BodyOf(values), epoch: epoch);
  }

  /// The form is open (`isClosed` turns true as soon as `close()` starts,
  /// which `close` below calls first) and still in its session.
  bool _canWrite(int epoch) => !isClosed && _session.epoch == epoch;

  void _onSessionChanged(Emitter<<<Pascal>>State> emit) {
    final epoch = _epoch;
    if (epoch == null || _ended || _session.epoch == epoch) {
      return;
    }
    if (_wizard?.state.isCompleting ?? false) {
      // A save is running: it re-checks the session once it settled.
      return;
    }
    _end(emit);
  }

  /// The session the form belongs to is gone: nothing more is written.
  void _end(Emitter<<<Pascal>>State> emit) {
    if (_ended || _flow.isCompleted) {
      return;
    }
    _ended = true;
    _wizard?.dispose();
    _wizard = null;
    _flow.update((s) => s.copyWith(step: 0));
    emit(const <<Pascal>>SessionEnded());
  }

  /// The flow's container disposes the bloc with the flow.
  @override
  @disposeMethod
  Future<void> close() async {
    // `super.close()` first: it closes the event stream at once, so
    // `isClosed` is true for every handler still awaiting something.
    final closed = super.close();
    _wizard?.dispose();
    await _flowChanges.cancel();
    await _sessionChanges.cancel();
    return closed;
  }
}''';

const messagesTemplate = r'''
/// What the user reads for a failed request, from the shared error copy.
/// The raw failure text goes to monitoring only (`McBloc`).
String failureMessage(ApiFailure failure, McL10nCoreL10n core) =>
    switch (failure) {
      ApiTimeout() => core.errorTimeout,
      ApiOffline() => core.errorNetwork,
      ApiServer() => core.errorServer,
      _ => core.errorGeneric,
    };

/// The message under [field] for [error] (the kit reports codes only).
/// `invalid` is the backend's verdict on a value it refused.
String fieldErrorMessage(
  String field,
  FieldError error,
  <<L10n>> l10n,
) => switch (field) {
<<cases>>  _ => l10n.<<fallback>>,
};''';

const pageTemplate = r'''
/// The key of the body of step [step] (0-based), for tests.
ValueKey<String> stepBodyKey(int step) =>
    ValueKey<String>('<<module>>.step.$step');

/// The key of the review's saving indicator, for tests.
const savingKey = ValueKey<String>('<<module>>.saving');

/// The key of the review's failed-save message, for tests.
const saveErrorKey = ValueKey<String>('<<module>>.save.error');

/// The key of the Close button of the session-ended page, for tests.
const closeKey = ValueKey<String>('<<module>>.close');

/// One page of the wizard: the fields of step [step], or the review. Every
/// step page shares the flow's bloc, so the page provides it with
/// `BlocProvider.value`; the flow's container closes it.
class <<Pascal>>StepPage extends StatelessWidget {
  const <<Pascal>>StepPage({required this.step, super.key});

  /// The step this page shows, 0-based.
  final int step;

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    // The only DI lookup in UI code (R17).
    value: context.di<<<Pascal>>Bloc>(),
    child: _StepPageContent(step: step),
  );
}

class _StepPageContent extends StatelessWidget {
  const _StepPageContent({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    final core = McL10nCoreL10n.of(context);
    return BlocBuilder<<<Pascal>>Bloc, <<Pascal>>State>(
      builder: (context, state) {
        final bloc = context.read<<<Pascal>>Bloc>();
        final saving = switch (state) {
          <<Pascal>>Editing(:final wizard) => wizard.isCompleting,
          _ => false,
        };
        return PopScope(
          // While the save runs the pages refuse to be popped, so the wizard
          // and the open pages never disagree.
          canPop: !saving,
          child: Scaffold(
            appBar: McAppBar(
              leading: const McFlowBackButton(),
              title: l10n.<<camel>>Title,
            ),
            body: switch (state) {
              <<Pascal>>Opening() => McLoading(
                semanticLabel: l10n.<<camel>>Title,
              ),
              <<Pascal>>SessionEnded() => Column(
                children: [
                  Expanded(
                    child: McEmptyView(
                      title: l10n.<<camel>>SessionEndedTitle,
                      message: l10n.<<camel>>SessionEndedMessage,
                    ),
                  ),
                  Padding(
                    padding: McInsets.screen,
                    child: McButton(
                      key: closeKey,
                      label: core.commonClose,
                      onPressed: () => bloc.add(const <<Pascal>>Event.close()),
                      expand: true,
                    ),
                  ),
                ],
              ),
              <<Pascal>>Editing(:final wizard) => _StepBody(
                step: step,
                wizard: wizard,
              ),
            },
            bottomNavigationBar: switch (state) {
              <<Pascal>>Editing(:final wizard) => _StepBar(
                step: step,
                wizard: wizard,
              ),
              _ => null,
            },
          ),
        );
      },
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.wizard});

  final int step;
  final WizardState<<<Result>>> wizard;

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    final bloc = context.read<<<Pascal>>Bloc>();
    final form = wizard.form;
<<review_locals>>    return ListView(
      key: stepBodyKey(step),
      padding: McInsets.screen,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: switch (step) {
<<step_cases>>        _ => const [],
      },
    );
  }
}

/// The step bar at the foot of each step page: "Step n of N", Back, and Next
/// (Create on the last step). Bound to the wizard only on the page of the
/// wizard's current step; a page below it shows its own step with both
/// buttons off.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.wizard});

  final int step;
  final WizardState<<<Result>>> wizard;

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    String stepLabel(int step, int total) => l10n.<<camel>>Step(step, total);
    final next = wizard.isLast ? l10n.<<camel>>Create : l10n.<<camel>>Next;
    if (wizard.stepIndex != step) {
      return McWizardStepper(
        currentStep: step,
        stepCount: wizard.stepCount,
        stepLabel: stepLabel,
        backLabel: l10n.<<camel>>Back,
        nextLabel: l10n.<<camel>>Next,
        onBack: null,
        onNext: null,
      );
    }
    final bloc = context.read<<<Pascal>>Bloc>();
    return McWizardStepper.fromState(
      wizard,
      stepLabel: stepLabel,
      backLabel: l10n.<<camel>>Back,
      nextLabel: next,
      finishLabel: next,
      onBack: () => bloc.add(const <<Pascal>>Event.back()),
      onNext: () => bloc.add(
        wizard.isLast
            ? const <<Pascal>>Event.submit()
            : const <<Pascal>>Event.next(),
      ),
      onBlockedNext: () => bloc.add(const <<Pascal>>Event.blockedNext()),
      blockedHint: l10n.<<camel>>BlockedHint,
    );
  }
}''';
