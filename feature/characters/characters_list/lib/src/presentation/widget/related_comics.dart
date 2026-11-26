import 'package:characters_list/src/l10n/characters_list_l10n.dart';
import 'package:characters_list/src/presentation/bloc/related_comics_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:mc_media/mc_media.dart';

/// Key of the preview's related comics, for tests.
const relatedComicsKey = ValueKey<String>('characters_list.preview.comics');

/// A related comic's cover thumbnail, portrait (3:4).
const double relatedComicCoverWidth = 36;
const double relatedComicCoverHeight = 48;

/// The preview's related comics: a section title, then the comics the
/// character appears in, each a link that leaves the feature (through the
/// bloc). Its failure is inline, with Retry; the preview above it stays.
class RelatedComics extends StatelessWidget {
  const RelatedComics({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = CharactersListL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    final bloc = context.read<RelatedComicsBloc>();
    return Column(
      key: relatedComicsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McSectionHeader(title: l10n.charactersListPreviewComics),
        BlocBuilder<RelatedComicsBloc, RelatedComicsState>(
          builder: (context, state) => state.when(
            loading: () => McLoading(
              semanticLabel: l10n.charactersListPreviewComicsLoading,
            ),
            failure: (_, _) => Padding(
              padding: McInsets.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.charactersListPreviewComicsFailed),
                  McButton(
                    label: core.commonRetry,
                    variant: McButtonVariant.tertiary,
                    onPressed: () => bloc.add(const RelatedComicsEvent.load()),
                  ),
                ],
              ),
            ),
            success: (comics) => comics.isEmpty
                ? Padding(
                    padding: McInsets.horizontal,
                    child: Text(l10n.charactersListPreviewComicsEmpty),
                  )
                : Column(
                    children: [
                      for (final comic in comics)
                        ListTile(
                          // The cover makes the row recognisable at a glance.
                          leading: McImage(
                            image: comic.cover,
                            variant: ImageVariant.portraitSmall,
                            width: relatedComicCoverWidth,
                            height: relatedComicCoverHeight,
                          ),
                          title: Text(comic.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              bloc.add(RelatedComicsEvent.open(comic.id)),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
