import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:library_reading_list_editor/src/presentation/bloc/comic_picker_bloc.dart';
import 'package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_bloc.dart';
import 'package:library_reading_list_editor/src/presentation/form/reading_list_form.dart';
import 'package:library_reading_list_editor/src/presentation/page/details_page.dart';
import 'package:library_reading_list_editor/src/presentation/widget/comic_row.dart';
import 'package:library_reading_list_editor/src/presentation/widget/editor_step_bar.dart';
import 'package:library_reading_list_editor/src/presentation/widget/messages.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Keys of step 2, for tests.
const comicResultsKey = ValueKey<String>('reading_list_editor.results');
const pickedComicsKey = ValueKey<String>('reading_list_editor.picked');
const comicsErrorKey = ValueKey<String>('reading_list_editor.comics.error');

/// Step 2: search the comics and toggle them into the list. The search is
/// this page's own bloc; what is picked is the wizard's (the editor bloc),
/// so it is kept when the user goes back to step 1 and returns.
class ReadingListComicsPage extends StatelessWidget {
  const ReadingListComicsPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      // The flow's editor bloc (shared by the steps), and the page's search.
      BlocProvider.value(value: context.di<ReadingListEditorBloc>()),
      BlocProvider(create: (context) => context.di<ComicPickerBloc>()),
    ],
    child: const _ComicsPageContent(),
  );
}

class _ComicsPageContent extends StatefulWidget {
  const _ComicsPageContent();

  @override
  State<_ComicsPageContent> createState() => _ComicsPageContentState();
}

class _ComicsPageContentState extends State<_ComicsPageContent> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    return BlocBuilder<ReadingListEditorBloc, ReadingListEditorState>(
      builder: (context, state) => Scaffold(
        appBar: McAppBar(
          leading: const McFlowBackButton(),
          title: l10n.readingListEditorComicsTitle,
        ),
        // The page is popped when the editor leaves the wizard (an ended
        // session goes back to step 1), so it only ever shows the wizard.
        body: state.maybeWhen(
          editing: (wizard, _) => _ComicsBody(wizard: wizard, query: _query),
          orElse: () => const SizedBox.shrink(),
        ),
        bottomNavigationBar: state.maybeWhen(
          editing: (wizard, existing) =>
              EditorStepBar(step: 1, wizard: wizard, existing: existing),
          orElse: () => null,
        ),
      ),
    );
  }
}

class _ComicsBody extends StatelessWidget {
  const _ComicsBody({required this.wizard, required this.query});

  final WizardState<ReadingListId> wizard;
  final TextEditingController query;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final editor = context.read<ReadingListEditorBloc>();
    final field = wizard.form.fieldOf<List<PickedComic>>(
      ReadingListFields.comics,
    );
    final picked = field.value ?? const <PickedComic>[];
    final error = field.visibleError;
    // The picked comics scroll with the results, so a long list of picks
    // never squeezes the results off the screen. The error sits right under
    // the count, above the picks, so it shows however many there are.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: McInsets.screen.copyWith(bottom: 0),
          child: McSearchField(
            controller: query,
            label: l10n.readingListEditorSearchLabel,
            clearLabel: l10n.readingListEditorSearchClear,
            onChanged: (text) => context.read<ComicPickerBloc>().add(
              ComicPickerEvent.queryChanged(text),
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: comicResultsKey,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: McInsets.screen,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.readingListEditorPickedCount(picked.length),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (error != null) ...[
                        const McGap.xs(),
                        FieldErrorText(
                          key: comicsErrorKey,
                          fieldErrorMessage(
                            ReadingListFields.comics,
                            error,
                            l10n,
                          ),
                        ),
                      ],
                      if (picked.isNotEmpty) ...[
                        const McGap.xs(),
                        McChipGroup<PickedComic>.multi(
                          key: pickedComicsKey,
                          options: [
                            for (final comic in picked)
                              McChipOption(value: comic, label: comic.title),
                          ],
                          selected: picked.toSet(),
                          // Tapping a picked chip deselects it: it leaves
                          // the list.
                          onChanged: (kept) {
                            for (final comic in picked) {
                              if (!kept.contains(comic)) {
                                editor.add(
                                  ReadingListEditorEvent.comicToggled(comic),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Results(picked: picked),
            ],
          ),
        ),
      ],
    );
  }
}

/// The search results, each a toggle: a sliver of the step's scroll view.
class _Results extends StatelessWidget {
  const _Results({required this.picked});

  final List<PickedComic> picked;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    final editor = context.read<ReadingListEditorBloc>();
    final ids = {for (final comic in picked) comic.id};
    return BlocBuilder<ComicPickerBloc, ComicPickerState>(
      builder: (context, state) => state.when(
        loading: (_) => SliverFillRemaining(
          hasScrollBody: false,
          child: McLoading(semanticLabel: l10n.readingListEditorSearching),
        ),
        empty: (query) => SliverFillRemaining(
          hasScrollBody: false,
          child: McEmptyView(
            title: l10n.readingListEditorSearchLabel,
            message: l10n.readingListEditorNoResults(query),
          ),
        ),
        failure: (error, _, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: McErrorView(
            title: l10n.readingListEditorSearchErrorTitle,
            message: failureMessage(error, core),
            retryLabel: core.commonRetry,
            onRetry: () => context.read<ComicPickerBloc>().add(
              const ComicPickerEvent.retry(),
            ),
          ),
        ),
        results: (_, comics) => SliverList.builder(
          itemCount: comics.length,
          itemBuilder: (context, i) {
            final comic = comics[i];
            return ComicRow(
              comic: comic,
              picked: ids.contains(comic.id),
              onTap: () =>
                  editor.add(ReadingListEditorEvent.comicToggled(comic)),
            );
          },
        ),
      ),
    );
  }
}
