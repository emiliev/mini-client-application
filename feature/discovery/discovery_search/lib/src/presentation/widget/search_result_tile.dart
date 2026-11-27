import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:discovery_search/src/presentation/bloc/discovery_search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_media/mc_media.dart';

/// A result's thumbnail, portrait (3:4).
const double searchResultArtWidth = 36;
const double searchResultArtHeight = 48;

/// The key of [hit]'s row, for tests: `discovery_search.result.<type>.<id>`.
ValueKey<String> searchResultKey(SearchHit hit) => ValueKey<String>(
  switch (hit) {
    CharacterHit(:final id) => 'discovery_search.result.character.${id.value}',
    ComicHit(:final id) => 'discovery_search.result.comic.${id.value}',
  },
);

/// One result: its art, its title and its subtitle (a character's team, a
/// comic's year). A tap hands it over to the app (through the bloc).
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({required this.hit, super.key});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final subtitle = hit.subtitle;
    return ListTile(
      key: searchResultKey(hit),
      leading: McImage(
        image: hit.image,
        variant: ImageVariant.portraitSmall,
        width: searchResultArtWidth,
        height: searchResultArtHeight,
      ),
      title: Text(hit.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.read<DiscoverySearchBloc>().add(
        DiscoverySearchEvent.open(hit),
      ),
    );
  }
}
