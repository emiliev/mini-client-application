import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:trivia_quiz/src/domain/engine/scoring.dart';
import 'package:trivia_quiz/src/presentation/bloc/trivia_play_bloc.dart';
import 'package:trivia_quiz/src/presentation/widget/countdown.dart';
import 'package:trivia_quiz/src/presentation/widget/streak_meter.dart';
import 'package:trivia_quiz/src/presentation/widget/trivia_common.dart';

/// Keys of the play page, for tests.
const playQuitKey = ValueKey<String>('trivia_play.quit');
const playPromptKey = ValueKey<String>('trivia_play.prompt');
const playNextKey = ValueKey<String>('trivia_play.next');
const playHintKey = ValueKey<String>('trivia_play.hint');
const playFeedbackKey = ValueKey<String>('trivia_play.feedback');
const playScoreKey = ValueKey<String>('trivia_play.score');
const playPausedKey = ValueKey<String>('trivia_play.paused');
ValueKey<String> playChoiceKey(String id) => ValueKey('trivia_play.choice.$id');

/// The mark on a judged choice: right (a check) or wrong (a cross).
const playChoiceCheckKey = ValueKey<String>('trivia_play.choice.check');
const playChoiceCrossKey = ValueKey<String>('trivia_play.choice.cross');

/// The play page: provides its bloc and nothing else (Tide).
class TriviaPlayPage extends StatelessWidget {
  const TriviaPlayPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<TriviaPlayBloc>(),
    child: const _PlayContent(),
  );
}

class _PlayContent extends StatefulWidget {
  const _PlayContent();

  @override
  State<_PlayContent> createState() => _PlayContentState();
}

/// Feeds the bloc what only Flutter knows: whether the round is visible
/// (the flow's route is current: no other screen, popup or the quit dialog
/// covers it) and whether the app is in the foreground. The rule: the
/// countdown runs only in `AppLifecycleState.resumed`; `inactive`, `hidden`
/// and `paused` (the app switcher, a call, the home screen) pause it, and it
/// resumes where it stopped (ADR-0014).
class _PlayContentState extends State<_PlayContent>
    with WidgetsBindingObserver {
  bool _started = false;
  bool? _shown;

  /// Asks to quit on any pop of the flow's own route while the round is on
  /// screen: the iOS back swipe and a system back would otherwise pop the
  /// whole flow, past this page's `PopScope` (which guards only the page's
  /// route inside the flow's navigator). Registered with the outer route, it
  /// also turns that route's back swipe off (review round).
  late final _QuitOnPop _outerPop = _QuitOnPop(
    () => context.read<TriviaPlayBloc>().add(
      const TriviaPlayEvent.quitAsked(),
    ),
  );
  ModalRoute<Object?>? _outerRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      context.read<TriviaPlayBloc>().add(
        const TriviaPlayEvent.foreground(foreground: false),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<TriviaPlayBloc>().add(
      TriviaPlayEvent.foreground(
        foreground: state == AppLifecycleState.resumed,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = FlowScope.maybeOf(context)?.outerRoute;
    if (outer != _outerRoute) {
      _outerRoute?.unregisterPopEntry(_outerPop);
      _outerRoute = outer;
      outer?.registerPopEntry(_outerPop);
    }
    final shown = FlowScope.maybeOf(context)?.outerIsCurrent ?? true;
    final bloc = context.read<TriviaPlayBloc>();
    if (shown != _shown) {
      _shown = shown;
      bloc.add(TriviaPlayEvent.shown(shown: shown));
    }
    if (shown && !_started) {
      _started = true;
      bloc.add(const TriviaPlayEvent.start());
    }
  }

  @override
  void dispose() {
    _outerRoute?.unregisterPopEntry(_outerPop);
    _outerPop.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _confirmQuit(BuildContext context) async {
    final l10n = context.triviaL10n;
    final bloc = context.read<TriviaPlayBloc>();
    final confirmed = await showMcConfirm(
      context,
      title: l10n.triviaQuitTitle,
      message: l10n.triviaQuitMessage,
      confirmLabel: l10n.triviaQuitConfirm,
      cancelLabel: l10n.triviaQuitCancel,
      destructive: true,
    );
    // The dialog can close because the page went away (a link replaced the
    // route): the bloc is closed then, and takes no events (review round).
    if (!bloc.isClosed) {
      bloc.add(TriviaPlayEvent.quitAnswered(confirmed: confirmed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final bloc = context.read<TriviaPlayBloc>();
    return BlocListener<TriviaPlayBloc, TriviaPlayState>(
      // The quit dialog opens when the bloc asks for it (it paused first).
      listenWhen: (previous, next) =>
          !_confirming(previous) && _confirming(next),
      listener: (context, _) => unawaited(_confirmQuit(context)),
      child: PopScope(
        // A pop of the page (the back gesture) asks to quit, like the close
        // button.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            bloc.add(const TriviaPlayEvent.quitAsked());
          }
        },
        child: BlocBuilder<TriviaPlayBloc, TriviaPlayState>(
          builder: (context, state) => Scaffold(
            appBar: McAppBar(
              leading: IconButton(
                key: playQuitKey,
                icon: const Icon(Icons.close),
                tooltip: l10n.triviaQuit,
                onPressed: () => bloc.add(const TriviaPlayEvent.quitAsked()),
              ),
              title: switch (state.whenOrNull(playing: (view) => view)) {
                final view? => l10n.triviaQuestionOf(view.number, view.total),
                null => l10n.triviaSetupTitle,
              },
            ),
            body: state.when(
              loading: () => const McLoading(),
              failure: (error, _) => McErrorView(
                title: l10n.triviaRoundError,
                message: failureMessage(context, error),
                retryLabel: McL10nCoreL10n.of(context).commonRetry,
                onRetry: () => bloc.add(const TriviaPlayEvent.retry()),
              ),
              playing: (view) => _QuestionView(view: view),
            ),
          ),
        ),
      ),
    );
  }
}

bool _confirming(TriviaPlayState state) =>
    state.whenOrNull(playing: (view) => view.confirmingQuit) ?? false;

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.view});

  final PlayView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    final bloc = context.read<TriviaPlayBloc>();
    final question = view.question;
    final answer = view.answer;
    final image = question.image;
    return ListView(
      padding: McInsets.screen,
      children: [
        Row(
          children: [
            Countdown(
              remainingMs: view.remainingMs,
              limitMs: question.limitMs,
              paused: view.paused && answer == null,
            ),
            const SizedBox(width: McSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.triviaScore(view.score),
                    key: playScoreKey,
                    style: text.titleMedium,
                  ),
                  const McGap.xs(),
                  StreakMeter(streak: view.streak),
                ],
              ),
            ),
            if (image != null) ...[
              const SizedBox(width: McSpacing.md),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: McRadius.smAll,
                  child: McImage(image: image, width: 56, height: 56),
                ),
              ),
            ],
          ],
        ),
        const McGap.lg(),
        Text(question.prompt, key: playPromptKey, style: text.titleLarge),
        const McGap.lg(),
        for (final choice in question.choices)
          if (!view.hidden.contains(choice.id)) ...[
            _ChoiceButton(
              key: playChoiceKey(choice.id),
              text: choice.text,
              look: _lookOf(choice.id),
              onPressed: answer == null
                  ? () => bloc.add(TriviaPlayEvent.answer(choice.id))
                  : null,
            ),
            const McGap.sm(),
          ],
        if (view.hintOffered) ...[
          const McGap.sm(),
          McButton(
            key: playHintKey,
            label: l10n.triviaHint,
            variant: McButtonVariant.tertiary,
            // Disabled while paused; the bloc refuses it then too.
            onPressed: view.paused
                ? null
                : () => bloc.add(const TriviaPlayEvent.useHint()),
          ),
        ],
        if (answer != null) ...[
          const McGap.md(),
          _Feedback(view: view),
          const McGap.lg(),
          McButton(
            key: playNextKey,
            label: view.isLast ? l10n.triviaSeeResults : l10n.triviaNext,
            expand: true,
            onPressed: () => bloc.add(const TriviaPlayEvent.next()),
          ),
        ],
      ],
    );
  }

  /// How a choice is drawn once the question is revealed. Only a judged
  /// choice is marked as chosen: after a timeout (a late tap included: it
  /// is judged a timeout, as the server judges it) the correct choice is
  /// revealed and nothing is marked as the player's (review round).
  _ChoiceLook _lookOf(String id) {
    final answer = view.answer;
    if (answer == null) {
      return _ChoiceLook.open;
    }
    final chosen =
        answer.outcome != AnswerOutcome.timeout && id == answer.choiceId;
    if (id == view.question.correctChoiceId) {
      return chosen ? _ChoiceLook.correct : _ChoiceLook.revealed;
    }
    return chosen ? _ChoiceLook.chosenWrong : _ChoiceLook.idle;
  }
}

/// `open` while asking; then `correct` (chosen and right, with a check),
/// `chosenWrong` (chosen and wrong, with a cross), `revealed` (the right
/// answer, not chosen: green, no icon) and `idle`.
enum _ChoiceLook { open, correct, chosenWrong, revealed, idle }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.text,
    required this.look,
    required this.onPressed,
    super.key,
  });

  final String text;
  final _ChoiceLook look;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final (border, icon) = switch (look) {
      _ChoiceLook.open || _ChoiceLook.idle => (p.outline, null),
      _ChoiceLook.correct => (p.success, Icons.check_circle),
      _ChoiceLook.revealed => (p.success, null),
      _ChoiceLook.chosenWrong => (p.error, Icons.cancel),
    };
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        foregroundColor: p.onSurface,
        disabledForegroundColor: p.onSurface,
        side: BorderSide(
          color: border,
          width: look == _ChoiceLook.open || look == _ChoiceLook.idle ? 1 : 2,
        ),
        shape: const RoundedRectangleBorder(borderRadius: McRadius.mdAll),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (icon != null)
            Icon(
              icon,
              color: border,
              key: icon == Icons.check_circle
                  ? playChoiceCheckKey
                  : playChoiceCrossKey,
            ),
        ],
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.view});

  final PlayView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    final answer = view.answer!;
    final question = view.question;
    final correctText = question.choices
        .firstWhere((c) => c.id == question.correctChoiceId)
        .text;
    final (title, color) = switch (answer.outcome) {
      AnswerOutcome.correct => (l10n.triviaCorrect(answer.points), p.success),
      AnswerOutcome.wrong => (l10n.triviaWrong, p.error),
      AnswerOutcome.timeout => (l10n.triviaTimeUp, p.error),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        key: playFeedbackKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium!.copyWith(color: color)),
          if (answer.outcome != AnswerOutcome.correct)
            Text(l10n.triviaAnswerWas(correctText), style: text.bodyMedium),
          if (answer.hint)
            Text(
              l10n.triviaHintUsed,
              style: text.bodySmall!.copyWith(color: p.onSurfaceMuted),
            ),
          Text(l10n.triviaStreak(answer.streak), style: text.bodySmall),
        ],
      ),
    );
  }
}

/// A pop of the outer route that never pops: it asks to quit instead.
class _QuitOnPop extends PopEntry<Object?> {
  _QuitOnPop(this._onQuit);

  final VoidCallback _onQuit;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(false);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop) {
      _onQuit();
    }
  }

  void dispose() => canPopNotifier.dispose();
}
