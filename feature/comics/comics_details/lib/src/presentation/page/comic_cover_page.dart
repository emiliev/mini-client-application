import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_media/mc_media.dart';

/// Key of the cover page's image, for tests.
const comicCoverPageImageKey = ValueKey<String>('comics_details.cover.image');

/// The comic's cover, full size, inside the flow (a flow page, not a route).
/// The flow keys it by the comic's id. It needs no bloc: the flow state
/// carries the loaded comic, and back is the app bar's automatic button or
/// the edge swipe.
class ComicCoverPage extends StatelessWidget {
  const ComicCoverPage({required this.comic, super.key});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final l10n = ComicsDetailsL10n.of(context);
    return Scaffold(
      // Inner page: the automatic back pops it (a flow page that can pop).
      appBar: McAppBar(title: comic.title),
      body: Padding(
        padding: McInsets.screen,
        child: Center(
          child: McImage(
            key: comicCoverPageImageKey,
            image: comic.cover,
            variant: ImageVariant.portraitLarge,
            fit: BoxFit.contain,
            semanticLabel: l10n.comicsDetailsCoverLabel(comic.title),
          ),
        ),
      ),
    );
  }
}
