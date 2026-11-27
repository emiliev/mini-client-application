import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:trivia_quiz/src/domain/model/round_seeds.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/domain/repository/trivia_quiz_repository.dart';
import 'package:trivia_quiz/src/flow/trivia_quiz_flow_state.dart';

part 'trivia_setup_bloc.freezed.dart';
part 'trivia_setup_event.dart';
part 'trivia_setup_state.dart';

/// The setup page: the categories (public) and, signed in, the user's best
/// score per category; the player picks a category and a difficulty and
/// starts a round.
///
/// - **Idle until shown.** The page adds `load` the first time it is shown
///   (F-0056 §1): under a cold `/trivia/play?...` link it is built below the
///   round and loads nothing until Back reveals it.
/// - **The best scores follow the session.** They are read for the session
///   epoch, pinned to it (T-0050); an answer for an epoch that is gone is
///   dropped and read again for the current one. A sign-in, sign-out or user
///   switch anywhere reads them again, and so does coming back to the page
///   (a round may have set a new best). A failed read shows no best: the
///   categories still work.
/// - **Start** puts the round in the flow state with a new seed; a second tap
///   while the round opens does nothing.
@injectable
final class TriviaSetupBloc extends McBloc<TriviaSetupEvent, TriviaSetupState> {
  TriviaSetupBloc(
    this._repository,
    this._flow,
    this._session,
    this._seeds,
    Monitoring monitoring,
  ) : super(const TriviaSetupState.loading(), monitoring: monitoring) {
    on<TriviaSetupEvent>(_onEvent);
  }

  final TriviaQuizRepository _repository;
  final FeatureFlowController<TriviaQuizFlowState> _flow;
  final SessionReader _session;
  final RoundSeeds _seeds;

  /// From the visit's start: a page built under another screen does not
  /// follow the session.
  StreamSubscription<AuthStatus>? _sessionChanges;

  /// Every best-score read bumps it; only the newest may write.
  int _bestReads = 0;

  Future<void> _onEvent(
    TriviaSetupEvent event,
    Emitter<TriviaSetupState> emit,
  ) async {
    switch (event) {
      case _Load():
        _sessionChanges ??= _session.authState.listen(
          (_) => add(const _SessionChanged()),
        );
        await _loadCategories(emit);
      case _Retry():
        if (state is _Failure) {
          await _loadCategories(emit);
        }
      case _ShownAgain() || _SessionChanged():
        if (state is _Ready) {
          await _loadBest(emit);
        }
      case _SelectCategory(:final id):
        if (state case final _Ready ready
            when ready.categories.any((c) => c.id == id)) {
          emit(ready.copyWith(category: id));
        }
      case _SelectDifficulty(:final difficulty):
        if (state case final _Ready ready) {
          emit(ready.copyWith(difficulty: difficulty));
        }
      case _Start():
        if (state case final _Ready ready when _flow.state.round == null) {
          _flow.update(
            (s) => s.copyWith(
              result: null,
              round: RoundRequest(
                category: ready.category,
                difficulty: ready.difficulty.name,
                seed: _seeds.next(),
              ),
            ),
          );
        }
    }
  }

  Future<void> _loadCategories(Emitter<TriviaSetupState> emit) async {
    emit(const TriviaSetupState.loading());
    final result = await _repository.fetchCategories();
    if (isClosed) {
      return;
    }
    final categories = result.fold<List<TriviaCategory>?>((c) => c, (error) {
      emit(TriviaSetupState.failure(error));
      return null;
    });
    if (categories == null) {
      return;
    }
    if (categories.isEmpty) {
      emit(const TriviaSetupState.empty());
      return;
    }
    emit(
      TriviaSetupState.ready(
        categories: categories,
        category: categories.first.id,
        difficulty: TriviaDifficulty.easy,
      ),
    );
    await _loadBest(emit);
  }

  /// Reads the best scores for the session now current (none signed out).
  Future<void> _loadBest(Emitter<TriviaSetupState> emit) async {
    final read = ++_bestReads;
    final epoch = _session.epoch;
    if (!_session.isSignedIn) {
      _showBest(emit, null);
      return;
    }
    final result = await _repository.fetchBest(epoch: epoch);
    if (isClosed || read != _bestReads) {
      return;
    }
    if (_session.epoch != epoch) {
      // An answer for a session that is gone: read again for this one (a
      // same-user re-sign-in has no `authState` event, F-0056 §2).
      add(const _SessionChanged());
      return;
    }
    _showBest(emit, result.fold((best) => best, (_) => null));
  }

  void _showBest(Emitter<TriviaSetupState> emit, Map<String, int>? best) {
    if (state case final _Ready ready) {
      emit(ready.copyWith(best: best));
    }
  }

  @override
  Future<void> close() {
    // Not awaited: a cancel future is made in the root zone and never
    // completes under a widget test's fake async (F-0052 trap 1).
    unawaited(_sessionChanges?.cancel());
    return super.close();
  }
}
