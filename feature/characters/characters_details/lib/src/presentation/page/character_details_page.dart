import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/l10n/characters_details_l10n.dart';
import 'package:characters_details/src/presentation/bloc/character_details_bloc.dart';
import 'package:characters_details/src/presentation/bloc/character_favourite_bloc.dart';
import 'package:characters_details/src/presentation/widget/character_comics.dart';
import 'package:characters_details/src/presentation/widget/character_facts.dart';
import 'package:characters_details/src/presentation/widget/character_header.dart';
import 'package:characters_details/src/presentation/widget/character_stats.dart';
import 'package:characters_details/src/presentation/widget/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Key of the profile page's scrolling body, for tests.
const characterDetailsBodyKey = ValueKey<String>('characters_details.body');

/// Key of the biography text, for tests.
const characterBioKey = ValueKey<String>('characters_details.bio');

/// The profile page: provides its blocs and nothing else (Tide).
class CharacterDetailsPage extends StatelessWidget {
  const CharacterDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The only DI lookups in UI code (R17). The favourite bloc is lazy: it
    // is created, and reads the flag, once the toggle first shows.
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => context.di<CharacterDetailsBloc>()),
        BlocProvider(
          create: (context) => context.di<CharacterFavouriteBloc>(),
        ),
      ],
      child: const _CharacterDetailsPageContent(),
    );
  }
}

/// Maps each bloc state to UI.
class _CharacterDetailsPageContent extends StatelessWidget {
  const _CharacterDetailsPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = CharacterDetailsL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    return BlocBuilder<CharacterDetailsBloc, CharacterDetailsState>(
      builder: (context, state) => Scaffold(
        appBar: McAppBar(
          // The flow has its own navigator: this leaves the flow from its
          // root page.
          leading: const McFlowBackButton(),
          title: state.maybeWhen(
            success: (character, _) => character.name,
            orElse: () => l10n.characterDetailsTitle,
          ),
        ),
        body: state.when(
          loading: () => McLoading(semanticLabel: l10n.characterDetailsLoading),
          notFound: () => McEmptyView(
            title: l10n.characterDetailsNotFoundTitle,
            message: l10n.characterDetailsNotFoundMessage,
          ),
          failure: (error, _) => McErrorView(
            title: l10n.characterDetailsErrorTitle,
            message: failureMessage(error, core),
            retryLabel: core.commonRetry,
            onRetry: () => context.read<CharacterDetailsBloc>().add(
              const CharacterDetailsEvent.load(),
            ),
          ),
          success: (character, comics) =>
              _CharacterSections(character: character, comics: comics),
        ),
      ),
    );
  }
}

/// The loaded character, section by section.
class _CharacterSections extends StatelessWidget {
  const _CharacterSections({required this.character, required this.comics});

  final Character character;
  final List<ComicSummary> comics;

  @override
  Widget build(BuildContext context) {
    final l10n = CharacterDetailsL10n.of(context);
    return ListView(
      key: characterDetailsBodyKey,
      padding: const EdgeInsets.only(bottom: McSpacing.xl),
      children: [
        CharacterHeader(character: character),
        McSectionHeader(title: l10n.characterDetailsBio),
        Padding(
          padding: McInsets.horizontal,
          child: Text(
            character.bio,
            key: characterBioKey,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        McSectionHeader(title: l10n.characterDetailsStats),
        CharacterStats(character: character),
        McSectionHeader(title: l10n.characterDetailsComics),
        CharacterComics(comics: comics),
        McSectionHeader(title: l10n.characterDetailsFacts),
        CharacterFacts(character: character),
      ],
    );
  }
}
