import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:trivia_quiz/src/domain/model/comic_id.dart';
import 'package:trivia_quiz/src/domain/model/round_seeds.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/domain/repository/trivia_quiz_repository.dart';
import 'package:trivia_quiz/src/flow/trivia_quiz_flow_state.dart';
import 'package:trivia_quiz/src/navigator/trivia_quiz_navigator.dart';

part 'trivia_results_bloc.freezed.dart';
part 'trivia_results_event.dart';
part 'trivia_results_state.dart';

/// How long after opening a comic a second open of the same comic is
/// ignored: the second tap of a double tap (the other exemplars' value).
const Duration openGuard = Duration(milliseconds: 500);

/// The local and the server's score of a round differ: the server's is
/// shown, and this is reported to monitoring once.
final class TriviaScoreMismatch implements Exception {
  const TriviaScoreMismatch(
    this.roundId, {
    required this.local,
    required this.server,
  });

  final String roundId;
  final int local;
  final int server;

  @override
  String toString() =>
      'TriviaScoreMismatch($roundId: local $local, server $server)';
}

/// The results page: saves the round on the server, which scores it again
/// (its score is authoritative), and shows the best score.
///
/// - **Signed in** when the page opens: the result is posted at once,
///   pinned to that session epoch (T-0050).
/// - **Signed out:** the page shows the local score and offers "Save your
///   score". A tap awaits `requestSignIn()`; on true, with someone signed
///   in, the result is posted for that user, pinned to the epoch read right
///   after the answer. On false nothing is sent.
/// - **Every await is a session boundary** (F-0040 fact 21). An answer that
///   arrives under another epoch than the one its post was pinned to is
///   dropped: nothing it says is shown, and the page offers to save for the
///   session now current (Retry signed in, the sign-in offer signed out). A
///   switch just before the post leaves is rejected before any bearer is
///   attached, so a result never goes out under another user's token.
/// - **A failed post** keeps the local score with "Not saved" and Retry;
///   Retry posts once (a second tap finds it saving).
/// - **The server's score wins.** When it differs from the engine's, the
///   server's is shown and [TriviaScoreMismatch] is reported once.
/// - **A comic** of a question opens through the navigator, once per tap
///   (a double tap opens it once).
@injectable
final class TriviaResultsBloc
    extends McBloc<TriviaResultsEvent, TriviaResultsState> {
  TriviaResultsBloc(
    this._repository,
    this._flow,
    this._navigator,
    this._session,
    this._seeds,
    Monitoring monitoring,
  ) : _monitoring = monitoring,
      finished = _flow.state.result!,
      super(const TriviaResultsState.saving(), monitoring: monitoring) {
    on<TriviaResultsEvent>(_onEvent);
  }

  final TriviaQuizRepository _repository;
  final FeatureFlowController<TriviaQuizFlowState> _flow;
  final TriviaQuizNavigator _navigator;
  final SessionReader _session;
  final RoundSeeds _seeds;
  final Monitoring _monitoring;

  /// The round this page shows, as the engine scored it.
  final FinishedRound finished;

  bool _started = false;
  bool _mismatchReported = false;
  Timer? _openGuard;
  ComicId? _opened;

  Future<void> _onEvent(
    TriviaResultsEvent event,
    Emitter<TriviaResultsState> emit,
  ) async {
    switch (event) {
      case _Start():
        if (_started) {
          return;
        }
        _started = true;
        if (_session.isSignedIn) {
          await _post(emit, _session.epoch);
        } else {
          emit(const TriviaResultsState.signedOut());
        }
      case _Save():
        await _signInAndPost(emit);
      case _Retry():
        if (state is! _NotSaved) {
          return;
        }
        if (_session.isSignedIn) {
          await _post(emit, _session.epoch);
        } else {
          emit(const TriviaResultsState.signedOut());
        }
      case _PlayAgain():
        if (_flow.state.result != null) {
          final round = finished.round;
          _flow.update(
            (s) => s.copyWith(
              result: null,
              round: RoundRequest(
                category: round.category,
                difficulty: round.difficulty.name,
                seed: _seeds.next(),
              ),
            ),
          );
        }
      case _OpenComic(:final id):
        if ((_openGuard?.isActive ?? false) && _opened == id) {
          return;
        }
        _openGuard?.cancel();
        _openGuard = Timer(openGuard, () {});
        _opened = id;
        _navigator.openComic(id);
    }
  }

  Future<void> _signInAndPost(Emitter<TriviaResultsState> emit) async {
    // One sign-in at a time: a second tap finds it signing in.
    if (state is! _SignedOut) {
      return;
    }
    emit(const TriviaResultsState.signingIn());
    final signedIn = await _navigator.requestSignIn();
    if (isClosed) {
      return;
    }
    if (!signedIn || !_session.isSignedIn) {
      emit(const TriviaResultsState.signedOut());
      return;
    }
    // The new user's session, read now: the post is for them only.
    await _post(emit, _session.epoch);
  }

  Future<void> _post(Emitter<TriviaResultsState> emit, int epoch) async {
    emit(const TriviaResultsState.saving());
    final result = await _repository.submit(
      finished.round.id,
      finished.answers,
      epoch: epoch,
    );
    if (isClosed) {
      return;
    }
    if (_session.epoch != epoch) {
      // The answer belongs to a session that is gone.
      emit(
        _session.isSignedIn
            ? const TriviaResultsState.notSaved(
                ApiUnauthorized('The session changed'),
              )
            : const TriviaResultsState.signedOut(),
      );
      return;
    }
    result.fold((server) {
      if (server.score != finished.score && !_mismatchReported) {
        _mismatchReported = true;
        unawaited(
          _monitoring.recordError(
            TriviaScoreMismatch(
              finished.round.id,
              local: finished.score,
              server: server.score,
            ),
            StackTrace.current,
          ),
        );
      }
      emit(TriviaResultsState.saved(server));
    }, (error) => emit(TriviaResultsState.notSaved(error)));
  }

  @override
  Future<void> close() {
    _openGuard?.cancel();
    return super.close();
  }
}
