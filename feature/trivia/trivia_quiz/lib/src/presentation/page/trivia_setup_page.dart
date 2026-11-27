import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/presentation/bloc/trivia_setup_bloc.dart';
import 'package:trivia_quiz/src/presentation/widget/trivia_common.dart';

/// Keys of the setup page, for tests.
const setupBodyKey = ValueKey<String>('trivia_setup.body');
const setupStartKey = ValueKey<String>('trivia_setup.start');
ValueKey<String> setupCategoryKey(String id) =>
    ValueKey('trivia_setup.category.$id');
ValueKey<String> setupBestKey(String id) => ValueKey('trivia_setup.best.$id');
ValueKey<String> setupDifficultyKey(TriviaDifficulty d) =>
    ValueKey('trivia_setup.difficulty.${d.name}');

/// The setup page: provides its bloc and nothing else (Tide).
class TriviaSetupPage extends StatelessWidget {
  const TriviaSetupPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<TriviaSetupBloc>(),
    child: const _SetupContent(),
  );
}

class _SetupContent extends StatefulWidget {
  const _SetupContent();

  @override
  State<_SetupContent> createState() => _SetupContentState();
}

class _SetupContentState extends State<_SetupContent> {
  bool _started = false;
  bool _visible = false;

  /// Depends on the flow's scope and on this page's own route, so it runs
  /// again when either changes: the page loads the first time it is shown
  /// (F-0056 §1), and reads the best scores again each time it is shown
  /// again (a round above it may have set a new best).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        (FlowScope.maybeOf(context)?.outerIsCurrent ?? true) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final bloc = context.read<TriviaSetupBloc>();
    if (visible && !_started) {
      _started = true;
      bloc.add(const TriviaSetupEvent.load());
    } else if (visible && !_visible) {
      bloc.add(const TriviaSetupEvent.shownAgain());
    }
    _visible = visible;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.triviaSetupTitle,
      ),
      body: BlocBuilder<TriviaSetupBloc, TriviaSetupState>(
        builder: (context, state) => state.when(
          loading: () => const McLoading(),
          failure: (error, _) => McErrorView(
            title: l10n.triviaSetupError,
            message: failureMessage(context, error),
            retryLabel: McL10nCoreL10n.of(context).commonRetry,
            onRetry: () => context.read<TriviaSetupBloc>().add(
              const TriviaSetupEvent.retry(),
            ),
          ),
          empty: () => McEmptyView(
            title: l10n.triviaEmptyTitle,
            message: l10n.triviaEmpty,
          ),
          ready: (categories, category, difficulty, best) => _SetupForm(
            categories: categories,
            category: category,
            difficulty: difficulty,
            best: best,
          ),
        ),
      ),
    );
  }
}

class _SetupForm extends StatelessWidget {
  const _SetupForm({
    required this.categories,
    required this.category,
    required this.difficulty,
    required this.best,
  });

  final List<TriviaCategory> categories;
  final String category;
  final TriviaDifficulty difficulty;
  final Map<String, int>? best;

  @override
  Widget build(BuildContext context) {
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    final bloc = context.read<TriviaSetupBloc>();
    return ListView(
      key: setupBodyKey,
      padding: McInsets.screen,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.triviaCategoryHeader, style: text.titleMedium),
        ),
        const McGap.sm(),
        for (final c in categories) ...[
          _CategoryTile(
            category: c,
            selected: c.id == category,
            best: best?[c.id],
            onTap: () => bloc.add(TriviaSetupEvent.selectCategory(c.id)),
          ),
          const McGap.sm(),
        ],
        const McGap.md(),
        Semantics(
          header: true,
          child: Text(l10n.triviaDifficultyHeader, style: text.titleMedium),
        ),
        const McGap.sm(),
        Wrap(
          spacing: McSpacing.sm,
          runSpacing: McSpacing.sm,
          children: [
            for (final d in TriviaDifficulty.values)
              ChoiceChip(
                key: setupDifficultyKey(d),
                selected: d == difficulty,
                onSelected: (_) =>
                    bloc.add(TriviaSetupEvent.selectDifficulty(d)),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(difficultyName(l10n, d)),
                    Text(
                      l10n.triviaSecondsPerQuestion(secondsPerQuestion[d]!),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const McGap.xl(),
        McButton(
          key: setupStartKey,
          label: l10n.triviaStart,
          expand: true,
          onPressed: () => bloc.add(const TriviaSetupEvent.start()),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.best,
    required this.onTap,
  });

  final TriviaCategory category;
  final bool selected;
  final int? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final l10n = context.triviaL10n;
    final text = Theme.of(context).textTheme;
    final best = this.best;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: setupCategoryKey(category.id),
        color: selected ? p.surfaceVariant : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: McRadius.mdAll,
          side: BorderSide(
            color: selected ? p.primary : p.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: McInsets.card,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: McRadius.smAll,
                    child: McImage(
                      image: category.image,
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
                const SizedBox(width: McSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: text.titleSmall),
                      Text(
                        l10n.triviaQuestionCount(category.questionCount),
                        style: text.bodySmall!.copyWith(
                          color: p.onSurfaceMuted,
                        ),
                      ),
                      if (best != null)
                        Text(
                          l10n.triviaBest(best),
                          key: setupBestKey(category.id),
                          style: text.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: p.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
