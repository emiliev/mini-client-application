// The search page and its recent-searches view (Tide 5.10: the page provides
// its bloc, the content maps states with `state.when`). The results widgets
// themselves (tiles, facets chips, grouped sections) are the module's own.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _page = 'lib/src/presentation/page';
const _widget = 'lib/src/presentation/widget';

void emitPages(EmitContext ctx, SrModel m) {
  ctx.dartBrick(
    'feature_list_detail_failure',
    const {},
    defines: {
      '$_widget/failure_message.dart': ['failureMessage'],
    },
  );
  final v = <String, String>{
    'module': m.module,
    'Pascal': m.pascal,
    'camel': m.camel,
    'Bloc': m.bloc,
    'Event': m.event,
    'State': m.state,
    'L10n': m.l10nClass,
    'Page': m.page,
    'Content': '_${m.page}Content',
    'ContentState': '_${m.page}ContentState',
    if (m.paged) ...{
      'Entity': m.entity,
      'Facets': m.name('facets'),
      'Tile': m.name('tile'),
      'tileArg': m.name('tile_arg'),
      'FacetsView': m.name('facets_view'),
      'emptyMessage': m.emptyMessage,
    } else ...{
      'Results': m.name('results'),
      'Filter': m.name('filter'),
      'ResultsView': m.name('results_view'),
    },
  };
  ctx.library(
    DartLibrary(
      '$_page/${m.module}_page.dart',
      imports: [
        if (m.paged) 'dart:async',
        if (m.paged) ...[
          m.uri('domain/model/${m.file('entity')}'),
          m.uri('domain/model/${m.file('facets')}'),
        ],
        m.uri('l10n/${m.module}_l10n.dart'),
        m.uri('presentation/bloc/${m.module}_bloc.dart'),
        if (m.paged) ...[
          m.uri('presentation/widget/${m.file('tile')}'),
          m.uri('presentation/widget/${m.file('empty_message')}'),
        ],
        m.uri('presentation/widget/failure_message.dart'),
        if (m.paged) m.uri('presentation/widget/${m.file('facets_view')}'),
        m.uri('presentation/widget/search_history_view.dart'),
        if (m.grouped) m.uri('presentation/widget/${m.file('results_view')}'),
        'package:flutter/material.dart',
        'package:flutter_bloc/flutter_bloc.dart',
        'package:mc_ds_feedback/mc_ds_feedback.dart',
        'package:mc_ds_inputs/mc_ds_inputs.dart',
        if (m.paged) 'package:mc_ds_lists/mc_ds_lists.dart',
        'package:mc_ds_navigation/mc_ds_navigation.dart',
        'package:mc_ds_tokens/mc_ds_tokens.dart',
        'package:mc_feature_flow/mc_feature_flow.dart',
        'package:mc_l10n_core/mc_l10n_core.dart',
      ],
      decls: [
        RawDecl(
          Code(
            tpl(m.paged ? _pagedPage : _groupedPage, {
              ...v,
              'd_content': doc(
                m,
                'page.content_doc',
                m.paged
                    ? 'The field, the facets, then each bloc state mapped to UI. Stateful only\n'
                          "for the field's controller: the text lives in the field, what it found in\n"
                          'the bloc.'
                    : 'The field, then each bloc state mapped to UI. Stateful only for the\n'
                          "field's controller: the text lives in the field, what it found in the\n"
                          'bloc.',
              ),
              'results_key': m.paged
                  ? '/// Key of the results list, for tests.\n'
                        "const searchResultsKey = ValueKey<String>('${m.module}.results');\n\n"
                  : '',
            }),
          ),
          name: m.page,
        ),
      ],
    ),
  );
  ctx.library(
    DartLibrary(
      '$_widget/search_history_view.dart',
      imports: [
        m.uri('l10n/${m.module}_l10n.dart'),
        m.uri('presentation/bloc/${m.module}_bloc.dart'),
        'package:flutter/material.dart',
        'package:flutter_bloc/flutter_bloc.dart',
        'package:mc_ds_layout/mc_ds_layout.dart',
        'package:mc_ds_navigation/mc_ds_navigation.dart',
        'package:mc_ds_theme/mc_ds_theme.dart',
      ],
      decls: [RawDecl(Code(tpl(_historyView, v)), name: 'SearchHistoryView')],
    ),
  );
}

const _pagedPage = r'''
/// Key of the search field, for tests.
const searchFieldKey = ValueKey<String>('<<module>>.field');

<<results_key>>/// The search page: provides its bloc and nothing else (Tide).
class <<Page>> extends StatelessWidget {
  const <<Page>>({this.initialQuery, super.key});

  /// The text the field starts with (the flow's argument).
  final String? initialQuery;

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<<<Bloc>>>(),
    child: <<Content>>(initialQuery: initialQuery),
  );
}

<<d_content>>class <<Content>> extends StatefulWidget {
  const <<Content>>({this.initialQuery});

  final String? initialQuery;

  @override
  State<<<Content>>> createState() =>
      <<ContentState>>();
}

class <<ContentState>>
    extends State<<<Content>>> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) => context.read<<<Bloc>>>().add(
    <<Event>>.queryChanged(text),
  );

  /// A recent search goes back into the field and is searched at once.
  void _searchAgain(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    context.read<<<Bloc>>>().add(
      <<Event>>.submitted(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    final core = McL10nCoreL10n.of(context);
    final bloc = context.read<<<Bloc>>>();
    void retry() => bloc.add(const <<Event>>.retry());
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.<<camel>>Title,
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
              label: l10n.<<camel>>FieldLabel,
              clearLabel: l10n.<<camel>>ClearQuery,
              onChanged: _changed,
              // The keyboard's Search key: search now, not after the
              // debounce.
              onSubmitted: (text) => bloc.add(
                <<Event>>.submitted(text),
              ),
              // Opened to type: the keyboard comes up. Opened with a query
              // (a link): the results are what the user came for.
              autofocus: widget.initialQuery == null,
            ),
          ),
          BlocBuilder<<<Bloc>>, <<State>>>(
            // The facets stay mounted (and keep their scroll position)
            // while a search goes from searching to results and back.
            buildWhen: (before, after) => _facetsOf(before) != _facetsOf(after),
            builder: (context, state) {
              final facets = _facetsOf(state);
              return facets == null
                  ? const SizedBox.shrink()
                  : <<FacetsView>>(facets: facets);
            },
          ),
          Expanded(
            child: BlocBuilder<<<Bloc>>, <<State>>>(
              builder: (context, state) => state.when(
                idle: (history, clearFailed) => SearchHistoryView(
                  history: history,
                  clearFailed: clearFailed,
                  onPick: _searchAgain,
                ),
                searching: (_, _) =>
                    McLoading(semanticLabel: l10n.<<camel>>Searching),
                // A new query or new facets start a new list: keyed by them,
                // it starts at the top instead of keeping the old scroll
                // position (which would be past the load-more threshold and
                // ask for page 2 at once).
                results: (query, page, facets) => KeyedSubtree(
                  key: ValueKey((query, facets)),
                  child: McPagedList<<<Entity>>>(
                    key: searchResultsKey,
                    state: page,
                    padding: EdgeInsets.zero,
                    separator: const SizedBox.shrink(),
                    itemBuilder: (context, <<tileArg>>, _) =>
                        <<Tile>>(<<tileArg>>: <<tileArg>>),
                    onLoadMore: () =>
                        bloc.add(const <<Event>>.loadMore()),
                    onRetry: retry,
                    onRefresh: () {
                      final done = Completer<void>();
                      bloc.add(<<Event>>.refresh(done));
                      return done.future;
                    },
                    emptyTitle: l10n.<<camel>>EmptyTitle,
                    emptyMessage: <<emptyMessage>>,
                    errorTitle: l10n.<<camel>>ErrorTitle,
                    footerErrorMessage: l10n.<<camel>>LoadMoreFailed,
                    retryLabel: core.commonRetry,
                    loadingLabel: l10n.<<camel>>Loading,
                  ),
                ),
                empty: (query, facets) => McEmptyView(
                  title: l10n.<<camel>>EmptyTitle,
                  message: <<emptyMessage>>,
                ),
                failure: (_, _, error, _) => McErrorView(
                  title: l10n.<<camel>>ErrorTitle,
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
  static <<Facets>>? _facetsOf(<<State>> state) => state.when(
    idle: (_, _) => null,
    searching: (_, facets) => facets,
    results: (_, _, facets) => facets,
    empty: (_, facets) => facets,
    failure: (_, facets, _, _) => facets,
  );
}''';

const _groupedPage = r'''
/// Key of the search field, for tests.
const searchFieldKey = ValueKey<String>('<<module>>.field');

/// The search page: provides its bloc and nothing else (Tide).
class <<Page>> extends StatelessWidget {
  const <<Page>>({this.initialQuery, super.key});

  /// The text the field starts with (the flow's argument).
  final String? initialQuery;

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (context) => context.di<<<Bloc>>>(),
    child: <<Content>>(initialQuery: initialQuery),
  );
}

<<d_content>>class <<Content>> extends StatefulWidget {
  const <<Content>>({this.initialQuery});

  final String? initialQuery;

  @override
  State<<<Content>>> createState() =>
      <<ContentState>>();
}

class <<ContentState>>
    extends State<<<Content>>> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) => context.read<<<Bloc>>>().add(
    <<Event>>.queryChanged(text),
  );

  /// A recent search goes back into the field and is searched at once.
  void _searchAgain(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    context.read<<<Bloc>>>().add(
      <<Event>>.submitted(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    final core = McL10nCoreL10n.of(context);
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.<<camel>>Title,
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
              label: l10n.<<camel>>FieldLabel,
              clearLabel: l10n.<<camel>>ClearQuery,
              onChanged: _changed,
              // The keyboard's Search key: search now, not after the
              // debounce.
              onSubmitted: (text) => context.read<<<Bloc>>>().add(
                <<Event>>.submitted(text),
              ),
              // Opened to type: the keyboard comes up. Opened with a query
              // (a link): the results are what the user came for.
              autofocus: widget.initialQuery == null,
            ),
          ),
          Expanded(
            child: BlocBuilder<<<Bloc>>, <<State>>>(
              builder: (context, state) => state.when(
                idle: (history, clearFailed) => SearchHistoryView(
                  history: history,
                  clearFailed: clearFailed,
                  onPick: _searchAgain,
                ),
                searching: (_) =>
                    McLoading(semanticLabel: l10n.<<camel>>Searching),
                results: (query, results, filter) => <<ResultsView>>(
                  query: query,
                  results: results,
                  filter: filter,
                ),
                empty: (query) => McEmptyView(
                  title: l10n.<<camel>>EmptyTitle,
                  message: l10n.<<camel>>EmptyMessage(query),
                ),
                failure: (_, error, _) => McErrorView(
                  title: l10n.<<camel>>ErrorTitle,
                  message: failureMessage(error, core),
                  retryLabel: core.commonRetry,
                  onRetry: () => context.read<<<Bloc>>>().add(
                    const <<Event>>.retry(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}''';

const _historyView = r'''
/// Key of the recent searches list, for tests.
const searchHistoryKey = ValueKey<String>('<<module>>.history');

/// Key of the inline error after a Clear that failed, for tests.
const searchClearFailedKey = ValueKey<String>(
  '<<module>>.history.clear_failed',
);

/// Key of the hint shown while there are no recent searches, for tests.
const searchNoHistoryKey = ValueKey<String>('<<module>>.history.none');

/// The recent searches, most recent first, with "Clear". Tapping one puts it
/// back in the field ([onPick]), which searches it at once. After a Clear
/// that failed ([clearFailed]) the list stays and an inline error says so.
class SearchHistoryView extends StatelessWidget {
  const SearchHistoryView({
    required this.history,
    required this.onPick,
    this.clearFailed = false,
    super.key,
  });

  final List<String> history;
  final bool clearFailed;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    if (history.isEmpty) {
      return Padding(
        key: searchNoHistoryKey,
        padding: McInsets.screen,
        child: Text(
          l10n.<<camel>>NoRecent,
          textAlign: TextAlign.center,
          style:
              Theme.of(
                    context,
                  ).textTheme.bodyLarge!
                  .copyWith(color: context.mcPalette.onSurfaceMuted),
        ),
      );
    }
    return ListView(
      key: searchHistoryKey,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        McSectionHeader(
          title: l10n.<<camel>>Recent,
          actionLabel: l10n.<<camel>>ClearRecent,
          onAction: () => context.read<<<Bloc>>>().add(
            const <<Event>>.clearHistory(),
          ),
        ),
        if (clearFailed)
          Padding(
            key: searchClearFailedKey,
            padding: McInsets.horizontal,
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.<<camel>>ClearFailed,
                style:
                    Theme.of(
                          context,
                        ).textTheme.bodyMedium!
                        .copyWith(color: context.mcPalette.error),
              ),
            ),
          ),
        for (final query in history)
          ListTile(
            leading: const ExcludeSemantics(child: Icon(Icons.history)),
            title: Text(query),
            onTap: () => onPick(query),
          ),
      ],
    );
  }
}''';
