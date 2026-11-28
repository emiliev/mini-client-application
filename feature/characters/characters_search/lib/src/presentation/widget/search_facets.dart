import 'package:characters_search/src/domain/model/character_facets.dart';
import 'package:characters_search/src/l10n/characters_search_l10n.dart';
import 'package:characters_search/src/presentation/bloc/characters_search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

/// Key of the sort chips, for tests.
const searchSortKey = ValueKey<String>('characters_search.facets.sort');

/// Key of the team chips, for tests.
const searchTeamKey = ValueKey<String>('characters_search.facets.team');

/// The facets over the results: how to sort, and which team to keep. Each
/// group is one scrolling row, so a long list of chips and a large text size
/// never overflow. A choice goes to the bloc, which searches the same query
/// again from the first page.
class SearchFacets extends StatelessWidget {
  const SearchFacets({required this.facets, super.key});

  final CharacterFacets facets;

  @override
  Widget build(BuildContext context) {
    final l10n = CharactersSearchL10n.of(context);
    final bloc = context.read<CharactersSearchBloc>();
    String sortLabel(CharacterSort sort) => switch (sort) {
      CharacterSort.nameAscending => l10n.charactersSearchSortNameAscending,
      CharacterSort.nameDescending => l10n.charactersSearchSortNameDescending,
      CharacterSort.newest => l10n.charactersSearchSortNewest,
      CharacterSort.oldest => l10n.charactersSearchSortOldest,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          label: l10n.charactersSearchSortLabel,
          child: McChipGroup<CharacterSort>.single(
            key: searchSortKey,
            options: [
              for (final sort in CharacterSort.values)
                McChipOption(value: sort, label: sortLabel(sort)),
            ],
            selected: facets.sort,
            onChanged: (picked) => bloc.add(
              CharactersSearchEvent.sortChanged(
                picked ?? CharacterSort.nameAscending,
              ),
            ),
          ),
        ),
        _Row(
          label: l10n.charactersSearchTeamLabel,
          child: McChipGroup<String>.single(
            key: searchTeamKey,
            options: [
              for (final team in characterTeams)
                McChipOption(value: team, label: team),
            ],
            selected: facets.team,
            // Tapping the chosen team again lets every team show.
            allowDeselect: true,
            onChanged: (picked) =>
                bloc.add(CharactersSearchEvent.teamChanged(picked)),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: McInsets.horizontal,
      child: child,
    ),
  );
}
