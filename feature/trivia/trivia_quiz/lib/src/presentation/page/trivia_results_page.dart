import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:trivia_quiz/src/domain/engine/scoring.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/flow/trivia_quiz_flow_state.dart';
import 'package:trivia_quiz/src/presentation/bloc/trivia_results_bloc.dart';
import 'package:trivia_quiz/src/presentation/widget/score_breakdown.dart';
import 'package:trivia_quiz/src/presentation/widget/trivia_common.dart';

/// Keys of the results page, for tests.
const resultsBodyKey = ValueKey<String>('trivia_results.body');
const resultsScoreKey = ValueKey<String>('trivia_results.score');
const resultsCorrectKey = ValueKey<String>('trivia_results.correct');
const resultsBestKey = ValueKey<String>('trivia_results.best');
const resultsNewBestKey = ValueKey<String>('trivia_results.new_best');
const resultsStatusKey = ValueKey<String>('trivia_results.status');
const resultsRetryKey = ValueKey<String>('trivia_results.retry');
const resultsSaveKey = ValueKey<String>('trivia_results.save');
const resultsPlayAgainKey = ValueKey<String>('trivia_results.play_again');
ValueKey<String> resultsComicKey(int index) =>
    ValueKey('trivia_results.comic.$index');
ValueKey<String> resultsQuestionKey(int index) =>
    ValueKey('trivia_results.question.$index');

/// The results page: provides its bloc and nothing else (Tide).
class TriviaResultsPage extends StatelessWidget {
  const TriviaResultsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<TriviaResultsBloc>(),
    child: const _ResultsContent(),
  );
}

class _ResultsContent extends StatefulWidget {
  const _ResultsContent();

  @override
  State<_ResultsContent> createState() => _ResultsContentState();
}

class _ResultsContentState extends State<_ResultsContent> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && (FlowScope.maybeOf(context)?.outerIsCurrent ?? true)) {
      _started = true;
      context.read<TriviaResultsBloc>().add(const TriviaResultsEvent.start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final bloc = context.read<TriviaResultsBloc>();
    final finished = bloc.finished;
    return Scaffold(
      appBar: McAppBar(
        leading: const McFlowBackButton(),
        title: l10n.triviaResultsTitle,
      ),
      body: BlocBuilder<TriviaResultsBloc, TriviaResultsState>(
        builder: (context, state) {
          final server = state.whenOrNull(saved: (result) => result);
          final points =
              server?.points ??
              [
                for (final a in finished.answers) a.points,
              ];
          return ListView(
            key: resultsBodyKey,
            padding: McInsets.screen,
            children: [
              _ScoreHeader(finished: finished, server: server),
              const McGap.md(),
              _SaveStatus(state: state),
              const McGap.lg(),
              ScoreBreakdown(finished: finished, points: points),
              const McGap.lg(),
              _QuestionList(finished: finished, points: points),
              const McGap.lg(),
              McButton(
                key: resultsPlayAgainKey,
                label: l10n.triviaPlayAgain,
                expand: true,
                onPressed: () => bloc.add(const TriviaResultsEvent.playAgain()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.finished, required this.server});

  final FinishedRound finished;
  final ServerResult? server;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    final server = this.server;
    // The server's score is authoritative once it is known.
    final score = server?.score ?? finished.score;
    final correct = server?.correct ?? finished.correct;
    return Column(
      children: [
        Text(
          '$score',
          key: resultsScoreKey,
          style: text.displaySmall,
          textAlign: TextAlign.center,
        ),
        Text(
          l10n.triviaCorrectCount(correct, finished.answers.length),
          key: resultsCorrectKey,
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (server != null) ...[
          const McGap.xs(),
          Text(
            l10n.triviaBestScore(server.bestScore),
            key: resultsBestKey,
            style: text.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (server.isNewBest)
            Text(
              l10n.triviaNewBest,
              key: resultsNewBestKey,
              style: text.titleSmall!.copyWith(
                color: context.mcPalette.success,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ],
    );
  }
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.state});

  final TriviaResultsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium!.copyWith(
      color: context.mcPalette.onSurfaceMuted,
    );
    final bloc = context.read<TriviaResultsBloc>();
    Widget message(String text) => Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: resultsStatusKey,
        style: muted,
        textAlign: TextAlign.center,
      ),
    );
    return state.when(
      saving: () => message(l10n.triviaSaving),
      saved: (_) => const SizedBox.shrink(),
      notSaved: (error, _) => Column(
        children: [
          message('${l10n.triviaNotSaved} ${failureMessage(context, error)}'),
          const McGap.sm(),
          McButton(
            key: resultsRetryKey,
            label: McL10nCoreL10n.of(context).commonRetry,
            variant: McButtonVariant.secondary,
            onPressed: () => bloc.add(const TriviaResultsEvent.retry()),
          ),
        ],
      ),
      signedOut: () => Column(
        children: [
          message(l10n.triviaSignedOut),
          const McGap.sm(),
          McButton(
            key: resultsSaveKey,
            label: l10n.triviaSaveScore,
            variant: McButtonVariant.secondary,
            onPressed: () => bloc.add(const TriviaResultsEvent.save()),
          ),
        ],
      ),
      signingIn: () => message(l10n.triviaSigningIn),
    );
  }
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({required this.finished, required this.points});

  final FinishedRound finished;
  final List<int> points;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    final p = context.mcPalette;
    final bloc = context.read<TriviaResultsBloc>();
    final questions = finished.round.questions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.triviaQuestionsTitle, style: text.titleMedium),
        ),
        const McGap.sm(),
        for (var i = 0; i < finished.answers.length; i++)
          Padding(
            key: resultsQuestionKey(i),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${questions[i].prompt}',
                  style: text.bodyMedium,
                ),
                Text(
                  [
                    switch (finished.answers[i].outcome) {
                      AnswerOutcome.correct => l10n.triviaOutcomeCorrect,
                      AnswerOutcome.wrong => l10n.triviaOutcomeWrong,
                      AnswerOutcome.timeout => l10n.triviaOutcomeTimeout,
                    },
                    l10n.triviaPoints(i < points.length ? points[i] : 0),
                    if (finished.answers[i].hint) l10n.triviaHintUsed,
                  ].join(' · '),
                  style: text.bodySmall!.copyWith(color: p.onSurfaceMuted),
                ),
                if (questions[i].comicId case final comic?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: resultsComicKey(i),
                      onPressed: () =>
                          bloc.add(TriviaResultsEvent.openComic(comic)),
                      child: Text(l10n.triviaAboutComic),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
