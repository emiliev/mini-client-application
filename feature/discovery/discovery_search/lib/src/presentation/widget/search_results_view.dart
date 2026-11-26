import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:discovery_search/src/l10n/discovery_search_l10n.dart';
import 'package:discovery_search/src/presentation/bloc/discovery_search_bloc.dart';
import 'package:discovery_search/src/presentation/widget/search_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Key of the results list, for tests.
const searchResultsKey = ValueKey<String>('discovery_search.results');

/// Key of the type chips, for tests.
const searchFiltersKey = ValueKey<String>('discovery_search.filters');

/// Key of [type]'s section header, for tests.
ValueKey<String> searchSectionKey(SearchType type) =>
    ValueKey<String>('discovery_search.section.${type.wireName}');

/// How many results of each type show under "All"; "Show 20" shows the rest
/// of the loaded page.
const int allFilterPreviewCount = 5;

/// The type chips over the results, grouped by type in the backend's order
/// (characters, then comics). Under "All" each group shows its first
/// [allFilterPreviewCount] results and a "Show 20" that picks its chip (it
/// promises only what is loaded; the title has the total); under one type,
/// that group's whole first page.
class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    required this.query,
    required this.results,
    required this.filter,
    super.key,
  });

  final String query;
  final SearchResults results;
  final SearchFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = DiscoverySearchL10n.of(context);
    final bloc = context.read<DiscoverySearchBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: McInsets.horizontal,
          child: McChipGroup<SearchFilter>.single(
            key: searchFiltersKey,
            options: [
              McChipOption(
                value: SearchFilter.all,
                label: l10n.discoverySearchFilterAll,
              ),
              McChipOption(
                value: SearchFilter.characters,
                label: l10n.discoverySearchCharacters,
              ),
              McChipOption(
                value: SearchFilter.comics,
                label: l10n.discoverySearchComics,
              ),
            ],
            selected: filter,
            onChanged: (picked) => bloc.add(
              DiscoverySearchEvent.filterChanged(picked ?? SearchFilter.all),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: searchResultsKey,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: McSpacing.xl),
            children: [
              for (final group in results.groups)
                if (filter.shows(group.type))
                  ..._section(context, l10n, bloc, group),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    DiscoverySearchL10n l10n,
    DiscoverySearchBloc bloc,
    SearchGroup group,
  ) {
    final preview = filter == SearchFilter.all;
    final shown = preview
        ? group.hits.take(allFilterPreviewCount).toList()
        : group.hits;
    final more = preview && group.total > shown.length;
    final style = Theme.of(context).textTheme.bodyMedium;
    return [
      McSectionHeader(
        key: searchSectionKey(group.type),
        title: switch (group.type) {
          SearchType.character => l10n.discoverySearchCharactersSection(
            group.total,
          ),
          SearchType.comic => l10n.discoverySearchComicsSection(group.total),
        },
        actionLabel: more
            ? l10n.discoverySearchShowMore(group.hits.length)
            : null,
        onAction: more
            ? () => bloc.add(
                DiscoverySearchEvent.filterChanged(
                  SearchFilter.only(group.type),
                ),
              )
            : null,
      ),
      if (group.hits.isEmpty)
        Padding(
          padding: McInsets.horizontal,
          child: Text(
            switch (group.type) {
              SearchType.character => l10n.discoverySearchNoCharacters(query),
              SearchType.comic => l10n.discoverySearchNoComics(query),
            },
            style: style,
          ),
        ),
      for (final hit in shown) SearchResultTile(hit: hit),
      if (!preview && group.total > shown.length)
        Padding(
          padding: McInsets.horizontal,
          child: Text(
            l10n.discoverySearchShowing(shown.length, group.total),
            style: style,
          ),
        ),
    ];
  }
}
