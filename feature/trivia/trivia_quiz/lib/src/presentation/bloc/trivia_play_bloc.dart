import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:trivia_quiz/src/domain/engine/trivia_engine.dart';
import 'package:trivia_quiz/src/domain/model/round_seeds.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/domain/model/trivia_analytics.dart';
import 'package:trivia_quiz/src/domain/repository/trivia_quiz_repository.dart';
import 'package:trivia_quiz/src/domain/time/trivia_ticker.dart';
import 'package:trivia_quiz/src/flags/trivia_quiz_flags.dart';
import 'package:trivia_quiz/src/flow/trivia_quiz_flow_state.dart';

part 'trivia_play_bloc.freezed.dart';
part 'trivia_play_event.dart';
part 'trivia_play_state.dart';

/// Why the countdown is not running.
enum _Pause {
  /// The app is not in the foreground (`AppLifecycleState` other than
  /// `resumed`).
  background,

  /// Another screen or a popup covers the round.
  covered,

  /// The quit dialog is open.
  quitDialog,
}

/// The play page: loads the round, wraps the engine, and runs the
/// countdown on the injected ticker (ADR-0014).
///
/// - **The engine judges, the bloc keeps time.** A question's elapsed time
///   is the [QuestionClock]'s reading when the answer arrives; the engine
///   scores it as the server will. A one-shot timer ends the question at its
///   limit exactly (`limit - 1` still counts), a periodic one redraws the
///   countdown every [TriviaTicker.frame].
/// - **The countdown runs only while someone can play.** It pauses while the
///   app is in the background, while another screen or a popup covers the
///   round, and while the quit dialog is open, and resumes from where it
///   stopped: paused time never counts.
/// - **Quit asks first.** A round in progress opens the confirm dialog
///   (paused); Cancel resumes, Confirm leaves the round. With no round yet
///   (loading, failed) it leaves at once.
/// - **The hint** (`trivia_hint` in the `hint` variant, read once per round)
///   hides two wrong choices once per round, on the question being asked.
/// - **Analytics:** `trivia_round_started` when the first question shows,
///   `trivia_answer` per question, `trivia_round_finished` with the engine's
///   score after the last.
@injectable
final class TriviaPlayBloc extends McBloc<TriviaPlayEvent, TriviaPlayState> {
  TriviaPlayBloc(
    this._repository,
    this._flow,
    this._flags,
    this._tracker,
    this._seeds,
    TriviaTicker ticker,
    Monitoring monitoring,
  ) : _ticker = ticker,
      _clock = QuestionClock(ticker.now),
      super(const TriviaPlayState.loading(), monitoring: monitoring) {
    on<TriviaPlayEvent>(_onEvent);
  }

  final TriviaQuizRepository _repository;
  final FeatureFlowController<TriviaQuizFlowState> _flow;
  final FeatureFlagsReader _flags;
  final AnalyticsTracker _tracker;
  final RoundSeeds _seeds;
  final TriviaTicker _ticker;
  final QuestionClock _clock;

  TriviaEngine? _engine;

  /// The round's seed: the request's, or one drawn once (a Retry plays the
  /// same round).
  int? _seed;
  bool _started = false;
  bool _hintOffered = false;
  bool _confirmingQuit = false;
  final Set<_Pause> _pauses = {};
  Timer? _frame;
  Timer? _due;

  Future<void> _onEvent(
    TriviaPlayEvent event,
    Emitter<TriviaPlayState> emit,
  ) async {
    switch (event) {
      case _Start():
        await _start(emit);
      case _Retry():
        if (state is _Failure) {
          await _load(emit);
        }
      case _Answer(:final choiceId):
        _answer(emit, choiceId);
      case _Tick():
        _tick(emit);
      case _TimeUp():
        _timeUp(emit);
      case _Next():
        _next(emit);
      case _UseHint():
        _useHint(emit);
      case _Foreground(:final foreground):
        _setPause(emit, _Pause.background, paused: !foreground);
      case _Shown(:final shown):
        _setPause(emit, _Pause.covered, paused: !shown);
      case _QuitAsked():
        _quitAsked(emit);
      case _QuitAnswered(:final confirmed):
        _quitAnswered(emit, confirmed);
    }
  }

  Future<void> _start(Emitter<TriviaPlayState> emit) async {
    if (_started) {
      return;
    }
    _started = true;
    await _load(emit);
  }

  Future<void> _load(Emitter<TriviaPlayState> emit) async {
    final request = _flow.state.round;
    if (request == null) {
      return;
    }
    emit(const TriviaPlayState.loading());
    final result = await _repository.fetchRound(
      category: request.category,
      difficulty: request.difficulty,
      seed: _seed ??= request.seed ?? _seeds.next(),
    );
    if (isClosed) {
      return;
    }
    result.fold((round) {
      _engine = TriviaEngine(round);
      _hintOffered = _flags.variant(triviaHint) == triviaHintOn;
      _tracker.roundStarted(round.category, round.difficulty.name);
      _ask(emit);
    }, (error) => emit(TriviaPlayState.failure(error)));
  }

  /// The current question starts: its clock from 0, its timers.
  void _ask(Emitter<TriviaPlayState> emit) {
    _clock.restart();
    if (_pauses.isNotEmpty) {
      _clock.pause();
    }
    _schedule();
    emit(TriviaPlayState.playing(_view()));
  }

  /// The timers for the question being asked, when nothing pauses it.
  void _schedule() {
    _frame?.cancel();
    _due?.cancel();
    final engine = _engine;
    if (engine == null ||
        engine.phase != RoundPhase.asking ||
        _pauses.isNotEmpty) {
      return;
    }
    _frame = _ticker.every(TriviaTicker.frame, () => _send(const _Tick()));
    _due = _ticker.after(
      Duration(milliseconds: engine.remainingMs(_clock.elapsedMs)),
      () => _send(const _TimeUp()),
    );
  }

  void _send(TriviaPlayEvent event) {
    if (!isClosed) {
      add(event);
    }
  }

  void _tick(Emitter<TriviaPlayState> emit) {
    if (_engine?.phase == RoundPhase.asking) {
      emit(TriviaPlayState.playing(_view()));
    }
  }

  void _timeUp(Emitter<TriviaPlayState> emit) {
    final engine = _engine;
    if (engine == null ||
        engine.phase != RoundPhase.asking ||
        _pauses.isNotEmpty) {
      return;
    }
    _reveal(emit, engine.timeOut());
  }

  void _answer(Emitter<TriviaPlayState> emit, String choiceId) {
    final engine = _engine;
    if (engine == null ||
        engine.phase != RoundPhase.asking ||
        _pauses.isNotEmpty ||
        engine.hiddenChoices.contains(choiceId)) {
      return;
    }
    _reveal(emit, engine.answer(choiceId, elapsedMs: _clock.elapsedMs));
  }

  void _reveal(Emitter<TriviaPlayState> emit, AnsweredQuestion answered) {
    _clock.pause();
    _schedule();
    _tracker.answered(
      answered.outcome,
      answered.elapsedMs,
      _engine!.question.limitMs,
    );
    emit(TriviaPlayState.playing(_view()));
  }

  void _next(Emitter<TriviaPlayState> emit) {
    final engine = _engine;
    if (engine == null || engine.phase != RoundPhase.revealed) {
      return;
    }
    engine.next();
    if (engine.phase == RoundPhase.finished) {
      _tracker.roundFinished(engine.score);
      _flow.update(
        (s) => s.copyWith(
          round: null,
          result: FinishedRound(
            round: engine.round,
            answers: engine.answers,
            score: engine.score,
            correct: engine.correct,
          ),
        ),
      );
      return;
    }
    _ask(emit);
  }

  void _useHint(Emitter<TriviaPlayState> emit) {
    final engine = _engine;
    if (engine == null || !_hintOffered || !engine.canUseHint) {
      return;
    }
    engine.useHint();
    emit(TriviaPlayState.playing(_view()));
  }

  void _setPause(
    Emitter<TriviaPlayState> emit,
    _Pause reason, {
    required bool paused,
  }) {
    final changed = paused ? _pauses.add(reason) : _pauses.remove(reason);
    final engine = _engine;
    if (!changed || engine == null) {
      return;
    }
    if (engine.phase == RoundPhase.asking) {
      if (_pauses.isEmpty) {
        _clock.resume();
      } else {
        _clock.pause();
      }
    }
    _schedule();
    if (engine.phase != RoundPhase.finished) {
      emit(TriviaPlayState.playing(_view()));
    }
  }

  void _quitAsked(Emitter<TriviaPlayState> emit) {
    final engine = _engine;
    if (engine == null) {
      // Nothing played yet (loading, or the round failed): leave at once.
      _leave();
      return;
    }
    if (_confirmingQuit) {
      return;
    }
    _confirmingQuit = true;
    _setPause(emit, _Pause.quitDialog, paused: true);
  }

  void _quitAnswered(Emitter<TriviaPlayState> emit, bool confirmed) {
    if (!_confirmingQuit) {
      return;
    }
    _confirmingQuit = false;
    if (confirmed) {
      _leave();
      return;
    }
    _setPause(emit, _Pause.quitDialog, paused: false);
  }

  /// Leaves the round: back to the setup page, or out of the flow when it
  /// was opened at the round.
  void _leave() {
    _frame?.cancel();
    _due?.cancel();
    if (_flow.state.linked) {
      _flow.complete();
    } else {
      _flow.update((s) => s.copyWith(round: null));
    }
  }

  PlayView _view() {
    final engine = _engine!;
    final revealed = engine.revealed;
    final elapsed = revealed?.elapsedMs ?? _clock.elapsedMs;
    return PlayView(
      question: engine.question,
      number: engine.index + 1,
      total: engine.total,
      remainingMs: engine.remainingMs(elapsed),
      answer: revealed,
      score: engine.score,
      streak: engine.streak,
      hidden: engine.hiddenChoices,
      hintOffered: _hintOffered && engine.canUseHint,
      paused: _pauses.isNotEmpty,
      confirmingQuit: _confirmingQuit,
      isLast: engine.isLast,
    );
  }

  @override
  Future<void> close() {
    _frame?.cancel();
    _due?.cancel();
    return super.close();
  }
}
