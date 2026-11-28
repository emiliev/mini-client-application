import 'dart:async';

import 'package:characters_search/src/domain/model/character.dart';
import 'package:characters_search/src/domain/model/character_facets.dart';
import 'package:characters_search/src/l10n/characters_search_l10n.dart';
import 'package:characters_search/src/presentation/bloc/characters_search_bloc.dart';
import 'package:characters_search/src/presentation/widget/character_result_tile.dart';
import 'package:characters_search/src/presentation/widget/empty_search_message.dart';
import 'package:characters_search/src/presentation/widget/failure_message.dart';
import 'package:characters_search/src/presentation/widget/search_facets.dart';
import 'package:characters_search/src/presentation/widget/search_history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Key of the search field, for tests.
const searchFieldKey = ValueKey<String>('characters_search.field');

/// Key of the results list, for tests.
const searchResultsKey = ValueKey<String>('characters_search.results');

/// The search page: provides its bloc and nothing else (Tide).
class CharactersSearchPage extends StatelessWidget {
  const CharactersSearchPage({this.initialQuery, super.key});

  /// The text the field starts with (the flow's argument).
  final String? initialQuery;

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<CharactersSearchBloc>(),
    child: _CharactersSearchPageContent(initialQuery: initialQuery),
  );
}

/// The field, the facets, then each bloc state mapped to UI. Stateful only
/// for the field's controller: the text lives in the field, what it found in
/// the bloc.
class _CharactersSearchPageContent extends StatefulWidget {
  const _CharactersSearchPageContent({this.initialQuery});

  final String? initialQuery;

  @override
  State<_CharactersSearchPageContent> createState() =>
      _CharactersSearchPageContentState();
}

class _CharactersSearchPageContentState
    extends State<_CharactersSearchPageContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) => context.read<CharactersSearchBloc>().add(
    CharactersSearchEvent.queryChanged(text),
  );

  /// A recent search goes back into the field and is searched at once.
  void _searchAgain(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    context.read<CharactersSearchBloc>().add(
      CharactersSearchEvent.submitted(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CharactersSearchL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    final bloc = context.read<CharactersSearchBloc>();
    void retry() => bloc.add(const CharactersSearchEvent.retry());
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.charactersSearchTitle,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McSpacing.lg,
              McSpacing.sm,
              McSpacing.lg,
              McSpacing.sm,
            ),
            child: McSearchField(
              key: searchFieldKey,
              controller: _controller,
              label: l10n.charactersSearchFieldLabel,
              clearLabel: l10n.charactersSearchClearQuery,
              onChanged: _changed,
              // The keyboard's Search key: search now, not after the
              // debounce.
              onSubmitted: (text) => bloc.add(
                CharactersSearchEvent.submitted(text),
              ),
              // Opened to type: the keyboard comes up. Opened with a query
              // (a link): the results are what the user came for.
              autofocus: widget.initialQuery == null,
            ),
          ),
          BlocBuilder<CharactersSearchBloc, CharactersSearchState>(
            // The facets stay mounted (and keep their scroll position)
            // while a search goes from searching to results and back.
            buildWhen: (before, after) => _facetsOf(before) != _facetsOf(after),
            builder: (context, state) {
              final facets = _facetsOf(state);
              return facets == null
                  ? const SizedBox.shrink()
                  : SearchFacets(facets: facets);
            },
          ),
          Expanded(
            child: BlocBuilder<CharactersSearchBloc, CharactersSearchState>(
              builder: (context, state) => state.when(
                idle: (history, clearFailed) => SearchHistoryView(
                  history: history,
                  clearFailed: clearFailed,
                  onPick: _searchAgain,
                ),
                searching: (_, _) =>
                    McLoading(semanticLabel: l10n.charactersSearchSearching),
                // A new query or new facets start a new list: keyed by them,
                // it starts at the top instead of keeping the old scroll
                // position (which would be past the load-more threshold and
                // ask for page 2 at once).
                results: (query, page, facets) => KeyedSubtree(
                  key: ValueKey((query, facets)),
                  child: McPagedList<Character>(
                    key: searchResultsKey,
                    state: page,
                    padding: EdgeInsets.zero,
                    separator: const SizedBox.shrink(),
                    itemBuilder: (context, character, _) =>
                        CharacterResultTile(character: character),
                    onLoadMore: () =>
                        bloc.add(const CharactersSearchEvent.loadMore()),
                    onRetry: retry,
                    onRefresh: () {
                      final done = Completer<void>();
                      bloc.add(CharactersSearchEvent.refresh(done));
                      return done.future;
                    },
                    emptyTitle: l10n.charactersSearchEmptyTitle,
                    emptyMessage: emptySearchMessage(l10n, query, facets.team),
                    errorTitle: l10n.charactersSearchErrorTitle,
                    footerErrorMessage: l10n.charactersSearchLoadMoreFailed,
                    retryLabel: core.commonRetry,
                    loadingLabel: l10n.charactersSearchLoading,
                  ),
                ),
                empty: (query, facets) => McEmptyView(
                  title: l10n.charactersSearchEmptyTitle,
                  message: emptySearchMessage(l10n, query, facets.team),
                ),
                failure: (_, _, error, _) => McErrorView(
                  title: l10n.charactersSearchErrorTitle,
                  message: failureMessage(error, core),
                  retryLabel: core.commonRetry,
                  onRetry: retry,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The facets a search shows, null while the recent searches show.
  static CharacterFacets? _facetsOf(CharactersSearchState state) => state.when(
    idle: (_, _) => null,
    searching: (_, facets) => facets,
    results: (_, _, facets) => facets,
    empty: (_, facets) => facets,
    failure: (_, facets, _, _) => facets,
  );
}
