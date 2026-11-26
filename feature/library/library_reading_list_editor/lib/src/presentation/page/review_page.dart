import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_bloc.dart';
import 'package:library_reading_list_editor/src/presentation/form/reading_list_form.dart';
import 'package:library_reading_list_editor/src/presentation/widget/editor_step_bar.dart';
import 'package:library_reading_list_editor/src/presentation/widget/messages.dart';
import 'package:library_reading_list_editor/src/presentation/widget/reading_order_row.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Keys of step 3, for tests.
const reviewBodyKey = ValueKey<String>('reading_list_editor.review');
const saveErrorKey = ValueKey<String>('reading_list_editor.save.error');
const savingKey = ValueKey<String>('reading_list_editor.saving');

/// Step 3: the details at a glance, the comics in reading order (drag
/// handles and arrows reorder them), and the save. A failed save shows an
/// inline error with Retry here; nothing entered is lost.
///
/// While the save runs the page refuses to be popped (a back gesture, the
/// app bar's back), so the wizard and the open pages never disagree.
class ReadingListReviewPage extends StatelessWidget {
  const ReadingListReviewPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: context.di<ReadingListEditorBloc>(),
    child: const _ReviewPageContent(),
  );
}

class _ReviewPageContent extends StatelessWidget {
  const _ReviewPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    return BlocBuilder<ReadingListEditorBloc, ReadingListEditorState>(
      builder: (context, state) {
        final saving = state.maybeWhen(
          editing: (wizard, _) => wizard.isCompleting,
          orElse: () => false,
        );
        return PopScope(
          canPop: !saving,
          child: Scaffold(
            appBar: McAppBar(
              leading: const McFlowBackButton(),
              title: l10n.readingListEditorReviewTitle,
            ),
            body: state.maybeWhen(
              editing: (wizard, _) => _ReviewBody(wizard: wizard),
              orElse: () => const SizedBox.shrink(),
            ),
            bottomNavigationBar: state.maybeWhen(
              editing: (wizard, existing) =>
                  EditorStepBar(step: 2, wizard: wizard, existing: existing),
              orElse: () => null,
            ),
          ),
        );
      },
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.wizard});

  final WizardState<ReadingListId> wizard;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReadingListEditorBloc>();
    final form = wizard.form;
    final comics =
        form.fieldOf<List<PickedComic>>(ReadingListFields.comics).value ??
        const <PickedComic>[];
    final busy = wizard.isCompleting;
    return ReorderableListView.builder(
      key: reviewBodyKey,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: McSpacing.xl),
      header: _Summary(wizard: wizard),
      itemCount: comics.length,
      onReorder: (from, to) => bloc.add(
        // Flutter counts the target before the item is removed.
        ReadingListEditorEvent.comicMoved(from, to > from ? to - 1 : to),
      ),
      itemBuilder: (context, i) => ReadingOrderRow(
        key: ValueKey<int>(comics[i].id.value),
        index: i,
        comic: comics[i],
        enabled: !busy,
        onUp: i == 0 || busy
            ? null
            : () => bloc.add(ReadingListEditorEvent.comicMoved(i, i - 1)),
        onDown: i == comics.length - 1 || busy
            ? null
            : () => bloc.add(ReadingListEditorEvent.comicMoved(i, i + 1)),
      ),
    );
  }
}

/// The details as entered, the save's status, and the reading order's
/// heading.
class _Summary extends StatelessWidget {
  const _Summary({required this.wizard});

  final WizardState<ReadingListId> wizard;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    final text = Theme.of(context).textTheme;
    final values = wizard.form.values;
    final description =
        values.get<String>(ReadingListFields.description) ?? '';
    final visibility =
        values.get<ReadingListVisibility>(ReadingListFields.visibility) ??
        ReadingListVisibility.private;
    final failure = wizard.failure;
    return Padding(
      padding: McInsets.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (values.get<String>(ReadingListFields.name) ?? '').trim(),
            style: text.headlineSmall,
          ),
          const McGap.xs(),
          Text(
            description.isEmpty
                ? l10n.readingListEditorNoDescription
                : description,
            style: text.bodyLarge,
          ),
          const McGap.xs(),
          Text(
            visibility == ReadingListVisibility.public
                ? l10n.readingListEditorPublic
                : l10n.readingListEditorPrivate,
            style: text.labelLarge,
          ),
          if (wizard.isCompleting) ...[
            const McGap.md(),
            Row(
              key: savingKey,
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const McGap.sm(),
                Expanded(child: Text(l10n.readingListEditorSaving)),
              ],
            ),
          ],
          if (failure != null) ...[
            const McGap.md(),
            _SaveError(
              message: failureMessage(failure, core),
              onRetry: () => context.read<ReadingListEditorBloc>().add(
                const ReadingListEditorEvent.submit(),
              ),
            ),
          ],
          const McGap.lg(),
          Semantics(
            header: true,
            child: Text(
              l10n.readingListEditorOrderTitle,
              style: text.titleMedium,
            ),
          ),
          const McGap.xs(),
          Text(l10n.readingListEditorOrderHint, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// The failed save: what went wrong and Retry, announced when it appears.
class _SaveError extends StatelessWidget {
  const _SaveError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    final p = context.mcPalette;
    return Semantics(
      key: saveErrorKey,
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.readingListEditorSaveFailed,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: p.error),
          ),
          const McGap.xs(),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const McGap.sm(),
          McButton(
            label: core.commonRetry,
            variant: McButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
