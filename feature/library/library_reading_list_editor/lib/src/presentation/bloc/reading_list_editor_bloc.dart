import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/domain/model/save_failure.dart';
import 'package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart';
import 'package:library_reading_list_editor/src/flow/reading_list_editor_flow_state.dart';
import 'package:library_reading_list_editor/src/navigator/reading_list_editor_navigator.dart';
import 'package:library_reading_list_editor/src/presentation/form/reading_list_form.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';

part 'reading_list_editor_bloc.freezed.dart';
part 'reading_list_editor_event.dart';
part 'reading_list_editor_state.dart';

/// The `mc_event_bus` topic a saved list announces, so whatever lists the
/// user's reading lists refreshes.
const String readingListsTopic = 'readingLists';

/// What a save returns when the session it was started for has ended. The
/// bloc then shows `sessionEnded`, whatever the save answered.
const ApiFailure _sessionChanged = ApiFailure.unauthorized(
  'The session changed',
);

/// The editor's bloc: one per flow (a lazy singleton of the flow's own
/// container), shared by the three step pages, so the wizard's values
/// outlive any one page (T-0048-AC6, "going back keeps every step's
/// values").
///
/// - **Sign-in gate:** signed out, it first awaits `requestSignIn()`; on
///   false the flow completes with no result.
/// - **Edit mode:** it reads the list and pre-fills every step. A save sends
///   `PUT` for the details and `PUT .../items` for the comics, each only when
///   it differs from what the backend holds; with no change it sends nothing
///   and completes with the same id.
/// - **The wizard:** `mc_forms`' `WizardController`, one form over all
///   steps. Its step is mirrored in the flow state, so each step is a page
///   and a back gesture is a step back; a pop the flow reports is applied to
///   the wizard.
/// - **One save at a time:** the wizard runs one completion, so a double
///   Finish sends one request.
/// - **The session decides:** the editor belongs to the session it opened
///   (or signed in) for. After every await before a write the epoch is
///   compared again (F-0040 fact 21), and a result that arrives for an
///   ended session is not handed out: the editor shows `sessionEnded` and
///   writes nothing more.
/// - **The result:** a saved list completes the flow with its id (the
///   wiring hands it back to the caller, plan 01 §4.3) and announces
///   `DataChanged('readingLists')` once.
/// - **The backend's verdicts:** a `400` naming a field goes back to that
///   field's step and shows the error under it ([ServerVerdicts]).
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter, so every generator that reads it runs on analyzer summaries.
@lazySingleton
final class ReadingListEditorBloc
    extends McBloc<ReadingListEditorEvent, ReadingListEditorState> {
  ReadingListEditorBloc(
    this._repository,
    this._flow,
    this._navigator,
    this._session,
    this._bus,
    Monitoring monitoring,
  ) : super(const ReadingListEditorState.loading(), monitoring: monitoring) {
    on<ReadingListEditorEvent>(_onEvent);
    _flowChanges = _flow.states.listen(_onFlowState);
    _sessionChanges = _session.authState.listen(
      (_) => add(const _SessionChanged()),
    );
    add(const _Start());
  }

  final ReadingListEditorRepository _repository;
  final FeatureFlowController<ReadingListEditorFlowState> _flow;
  final ReadingListEditorNavigator _navigator;
  final SessionReader _session;
  final EventBus _bus;
  late final StreamSubscription<ReadingListEditorFlowState> _flowChanges;
  late final StreamSubscription<AuthStatus> _sessionChanges;
  final ServerVerdicts _verdicts = ServerVerdicts();

  /// Null until the editor has a signed-in session (and, in edit mode, the
  /// list), and again once that session ended.
  WizardController<ReadingListId>? _wizard;

  /// The session epoch the editor belongs to; null until it has one.
  int? _epoch;

  /// Edit mode: the list as the backend holds it after the last read or
  /// write, so a save sends only what differs.
  ReadingList? _saved;

  /// The field the last save's `400` named, until the save returned.
  SaveRejected? _rejection;

  bool _loading = false;
  bool _ended = false;

  ReadingListId? get _editing => _flow.state.editing;

  Future<void> _onEvent(
    ReadingListEditorEvent event,
    Emitter<ReadingListEditorState> emit,
  ) async {
    final wizard = _wizard;
    switch (event) {
      case _Start():
        await _start(emit);
      case _Retry():
        if (state is _LoadFailed) {
          await _load(emit);
        }
      case _WizardChanged(:final wizard):
        if (_wizard != null) {
          emit(
            ReadingListEditorState.editing(wizard, existing: _editing != null),
          );
        }
      case _NameChanged(:final name):
        wizard?.setValue(ReadingListFields.name, name);
      case _DescriptionChanged(:final text):
        wizard?.setValue(ReadingListFields.description, text);
      case _VisibilityChanged(:final visibility):
        wizard?.setValue(ReadingListFields.visibility, visibility);
      case _Touched(:final field):
        wizard?.touch(field);
      case _ComicToggled(:final comic):
        if (wizard != null) {
          final comics = _comicsOf(wizard);
          final picked = comics.any((c) => c.id == comic.id);
          wizard.setValue(ReadingListFields.comics, [
            for (final c in comics)
              if (c.id != comic.id) c,
            if (!picked) comic,
          ]);
        }
      case _ComicMoved(:final from, :final to):
        if (wizard != null) {
          final comics = [..._comicsOf(wizard)];
          if (from != to &&
              from >= 0 &&
              to >= 0 &&
              from < comics.length &&
              to < comics.length) {
            comics.insert(to, comics.removeAt(from));
            wizard.setValue(ReadingListFields.comics, comics);
          }
        }
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

  /// The sign-in gate, then the wizard (create) or the load (edit).
  Future<void> _start(Emitter<ReadingListEditorState> emit) async {
    if (!_session.isSignedIn) {
      emit(const ReadingListEditorState.signingIn());
      final signedIn = await _navigator.requestSignIn();
      if (!signedIn || !_session.isSignedIn) {
        // The user backed out: the editor closes with no result.
        _flow.complete();
        return;
      }
    }
    _epoch = _session.epoch;
    if (_editing == null) {
      _open(null);
    } else {
      await _load(emit);
    }
  }

  /// Edit mode: reads the list, then pre-fills the wizard with it.
  Future<void> _load(Emitter<ReadingListEditorState> emit) async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      emit(const ReadingListEditorState.loading());
      final epoch = _epoch;
      final result = await _repository.fetchList(_editing!);
      if (_session.epoch != epoch) {
        // Read for a session that is gone: not this user's list to show.
        _end(emit);
        return;
      }
      result.fold(
        (list) {
          _saved = list;
          _open(list);
        },
        (failure) => emit(
          failure is ApiNotFound
              ? const ReadingListEditorState.notFound()
              : ReadingListEditorState.loadFailed(failure),
        ),
      );
    } finally {
      _loading = false;
    }
  }

  void _open(ReadingList? saved) {
    final wizard = WizardController<ReadingListId>(
      steps: readingListSteps(verdicts: _verdicts, saved: saved),
      onState: _onWizardState,
      onComplete: _save,
    );
    _wizard = wizard;
    add(_WizardChanged(wizard.state));
  }

  /// The wizard's step is the flow's: a step change opens or closes step
  /// pages. Then the state comes back into the bloc as an event.
  void _onWizardState(WizardState<ReadingListId> wizard) {
    if (_flow.state.step != wizard.stepIndex) {
      _flow.update((s) => s.copyWith(step: wizard.stepIndex));
    }
    add(_WizardChanged(wizard));
  }

  /// A step page was popped (a back gesture, the app bar's back): the
  /// wizard goes back with it, keeping every value. While a save runs the
  /// review page refuses the pop, so the two never disagree.
  void _onFlowState(ReadingListEditorFlowState flow) {
    final wizard = _wizard;
    if (wizard == null) {
      return;
    }
    while (flow.step < wizard.state.stepIndex && wizard.back()) {}
  }

  Future<void> _submit(
    WizardController<ReadingListId> wizard,
    Emitter<ReadingListEditorState> emit,
  ) async {
    final outcome = await wizard.complete();
    if (outcome == null) {
      // Invalid (the wizard shows the first invalid step), or a save is
      // already running: a double Finish sends one request.
      return;
    }
    if (_session.epoch != _epoch) {
      // Whatever the save answered, it belongs to a session that is gone.
      _end(emit);
      return;
    }
    outcome.fold(
      (id) {
        _bus.publish(const DataChanged(readingListsTopic));
        _flow.complete(id);
      },
      (_) {
        final rejection = _rejection;
        _rejection = null;
        if (rejection != null) {
          _showVerdict(wizard, rejection);
        }
      },
    );
  }

  /// The wizard's completion: create, or write what changed. Every write is
  /// sent only while the editor's session is current, checked after each
  /// await (a session change between two writes stops the second).
  Future<Result<ReadingListId, ApiFailure>> _save(FormValues values) async {
    _rejection = null;
    final epoch = _epoch;
    final draft = readingListDraftOf(values);
    final editing = _editing;
    if (editing == null) {
      if (_session.epoch != epoch) {
        return failure(_sessionChanged);
      }
      return _settle(await _repository.create(draft));
    }
    var saved = _saved!;
    if (draft.detailsDifferFrom(saved)) {
      if (_session.epoch != epoch) {
        return failure(_sessionChanged);
      }
      final written = await _repository.updateDetails(editing, draft);
      final list = written.getOrNull();
      if (list == null) {
        return _settle(written);
      }
      saved = _saved = list;
    }
    if (draft.itemsDifferFrom(saved)) {
      if (_session.epoch != epoch) {
        return failure(_sessionChanged);
      }
      final written = await _repository.replaceItems(editing, draft);
      final list = written.getOrNull();
      if (list == null) {
        return _settle(written);
      }
      _saved = list;
    }
    return success(editing);
  }

  /// The kit completes with an `ApiFailure`; a field the backend refused is
  /// kept aside and shown once the completion returned.
  Result<ReadingListId, ApiFailure> _settle(
    Result<ReadingList, SaveFailure> written,
  ) => written.fold((list) => success(list.id), (error) {
    if (error is SaveRejected) {
      _rejection = error;
    }
    return failure(error.asApiFailure);
  });

  /// The backend refused a field: its value now fails a rule (so the step
  /// is invalid and the error shows under the field), and the wizard goes
  /// back to the field's step (T-0048-AC2).
  void _showVerdict(
    WizardController<ReadingListId> wizard,
    SaveRejected rejection,
  ) {
    final name = ReadingListFields.of(rejection.field);
    final value = wizard.state.form.field(name).value;
    _verdicts.refuse(
      rejection.field,
      wireValueOf(rejection.field, value),
      verdictFor(rejection),
    );
    // The same value again: the form re-checks every rule, now with the
    // verdict, and leaves the failed save.
    wizard.setValue(name, value);
    final step = ReadingListSteps.indexOf(rejection.field);
    while (wizard.state.stepIndex > step && wizard.back()) {}
  }

  void _onSessionChanged(Emitter<ReadingListEditorState> emit) {
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

  /// The session the editor belongs to is gone: nothing more is written.
  void _end(Emitter<ReadingListEditorState> emit) {
    if (_ended || _flow.isCompleted) {
      return;
    }
    _ended = true;
    _wizard?.dispose();
    _wizard = null;
    _flow.update((s) => s.copyWith(step: 0));
    emit(const ReadingListEditorState.sessionEnded());
  }

  static List<PickedComic> _comicsOf(WizardController<ReadingListId> wizard) =>
      wizard.state.form
          .fieldOf<List<PickedComic>>(ReadingListFields.comics)
          .value ??
      const [];

  /// The flow's container disposes the bloc with the flow.
  @override
  @disposeMethod
  Future<void> close() async {
    await _flowChanges.cancel();
    await _sessionChanges.cancel();
    _wizard?.dispose();
    return super.close();
  }
}
