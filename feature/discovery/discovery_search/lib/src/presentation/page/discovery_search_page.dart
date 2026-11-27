import 'package:discovery_search/src/l10n/discovery_search_l10n.dart';
import 'package:discovery_search/src/presentation/bloc/discovery_search_bloc.dart';
import 'package:discovery_search/src/presentation/widget/failure_message.dart';
import 'package:discovery_search/src/presentation/widget/search_history_view.dart';
import 'package:discovery_search/src/presentation/widget/search_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Key of the search field, for tests.
const searchFieldKey = ValueKey<String>('discovery_search.field');

/// The search page: provides its bloc and nothing else (Tide).
class DiscoverySearchPage extends StatelessWidget {
  const DiscoverySearchPage({this.initialQuery, super.key});

  /// The text the field starts with (the flow's argument).
  final String? initialQuery;

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<DiscoverySearchBloc>(),
    child: _DiscoverySearchPageContent(initialQuery: initialQuery),
  );
}

/// The field, then each bloc state mapped to UI. Stateful only for the
/// field's controller: the text lives in the field, what it found in the
/// bloc.
class _DiscoverySearchPageContent extends StatefulWidget {
  const _DiscoverySearchPageContent({this.initialQuery});

  final String? initialQuery;

  @override
  State<_DiscoverySearchPageContent> createState() =>
      _DiscoverySearchPageContentState();
}

class _DiscoverySearchPageContentState
    extends State<_DiscoverySearchPageContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) => context.read<DiscoverySearchBloc>().add(
    DiscoverySearchEvent.queryChanged(text),
  );

  /// A recent search goes back into the field and is searched at once.
  void _searchAgain(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    context.read<DiscoverySearchBloc>().add(
      DiscoverySearchEvent.submitted(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = DiscoverySearchL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.discoverySearchTitle,
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
              label: l10n.discoverySearchFieldLabel,
              clearLabel: l10n.discoverySearchClearQuery,
              onChanged: _changed,
              // The keyboard's Search key: search now, not after the
              // debounce.
              onSubmitted: (text) => context.read<DiscoverySearchBloc>().add(
                DiscoverySearchEvent.submitted(text),
              ),
              // Opened to type: the keyboard comes up. Opened with a query
              // (a link): the results are what the user came for.
              autofocus: widget.initialQuery == null,
            ),
          ),
          Expanded(
            child: BlocBuilder<DiscoverySearchBloc, DiscoverySearchState>(
              builder: (context, state) => state.when(
                idle: (history, clearFailed) => SearchHistoryView(
                  history: history,
                  clearFailed: clearFailed,
                  onPick: _searchAgain,
                ),
                searching: (_) =>
                    McLoading(semanticLabel: l10n.discoverySearchSearching),
                results: (query, results, filter) => SearchResultsView(
                  query: query,
                  results: results,
                  filter: filter,
                ),
                empty: (query) => McEmptyView(
                  title: l10n.discoverySearchEmptyTitle,
                  message: l10n.discoverySearchEmptyMessage(query),
                ),
                failure: (_, error, _) => McErrorView(
                  title: l10n.discoverySearchErrorTitle,
                  message: failureMessage(error, core),
                  retryLabel: core.commonRetry,
                  onRetry: () => context.read<DiscoverySearchBloc>().add(
                    const DiscoverySearchEvent.retry(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
