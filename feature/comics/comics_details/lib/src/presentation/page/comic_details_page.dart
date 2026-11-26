import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:comics_details/src/presentation/bloc/comic_details_bloc.dart';
import 'package:comics_details/src/presentation/bloc/comic_favourite_bloc.dart';
import 'package:comics_details/src/presentation/widget/comic_cast.dart';
import 'package:comics_details/src/presentation/widget/comic_credits.dart';
import 'package:comics_details/src/presentation/widget/comic_facts.dart';
import 'package:comics_details/src/presentation/widget/comic_header.dart';
import 'package:comics_details/src/presentation/widget/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Key of the details page's scrolling body, for tests.
const comicDetailsBodyKey = ValueKey<String>('comics_details.body');

/// The details page: provides its blocs and nothing else (Tide).
class ComicDetailsPage extends StatelessWidget {
  const ComicDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The only DI lookups in UI code (R17). The favourite bloc is lazy: it
    // is created, and reads the flag, once the toggle first shows.
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => context.di<ComicDetailsBloc>()),
        BlocProvider(create: (context) => context.di<ComicFavouriteBloc>()),
      ],
      child: const _ComicDetailsPageContent(),
    );
  }
}

/// Maps each bloc state to UI.
class _ComicDetailsPageContent extends StatelessWidget {
  const _ComicDetailsPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = ComicsDetailsL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    return BlocBuilder<ComicDetailsBloc, ComicDetailsState>(
      builder: (context, state) => Scaffold(
        appBar: McAppBar(
          // The flow has its own navigator: this leaves the flow from its
          // root page.
          leading: const McFlowBackButton(),
          title: state.maybeWhen(
            success: (comic) => comic.title,
            orElse: () => l10n.comicsDetailsTitle,
          ),
        ),
        body: state.when(
          loading: () => McLoading(semanticLabel: l10n.comicsDetailsLoading),
          notFound: () => McEmptyView(
            title: l10n.comicsDetailsNotFoundTitle,
            message: l10n.comicsDetailsNotFoundMessage,
          ),
          failure: (error, _) => McErrorView(
            title: l10n.comicsDetailsErrorTitle,
            message: failureMessage(error, core),
            retryLabel: core.commonRetry,
            onRetry: () => context.read<ComicDetailsBloc>().add(
              const ComicDetailsEvent.load(),
            ),
          ),
          success: (comic) => _ComicSections(comic: comic),
        ),
      ),
    );
  }
}

/// The loaded comic, section by section.
class _ComicSections extends StatelessWidget {
  const _ComicSections({required this.comic});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final l10n = ComicsDetailsL10n.of(context);
    return ListView(
      key: comicDetailsBodyKey,
      padding: const EdgeInsets.only(bottom: McSpacing.xl),
      children: [
        ComicHeader(comic: comic),
        McSectionHeader(title: l10n.comicsDetailsSynopsis),
        Padding(
          padding: McInsets.horizontal,
          child: Text(
            comic.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        McSectionHeader(title: l10n.comicsDetailsFacts),
        ComicFacts(comic: comic),
        McSectionHeader(title: l10n.comicsDetailsCreators),
        ComicCredits(credits: comic.creators),
        if (comic.cast.isNotEmpty) ...[
          McSectionHeader(title: l10n.comicsDetailsCharacters),
          ComicCast(cast: comic.cast),
        ],
      ],
    );
  }
}
