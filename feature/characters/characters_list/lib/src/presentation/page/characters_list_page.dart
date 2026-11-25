import 'dart:async';

import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/l10n/characters_list_l10n.dart';
import 'package:characters_list/src/presentation/bloc/characters_list_bloc.dart';
import 'package:characters_list/src/presentation/widget/character_tile.dart';
import 'package:characters_list/src/presentation/widget/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Key of the characters grid, for tests.
const charactersGridKey = ValueKey<String>('characters_list.grid');

/// The list page: provides its bloc and nothing else (Tide).
class CharactersListPage extends StatelessWidget {
  const CharactersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The only DI lookup in UI code (R17). The flow's container is read here,
    // in build: `context.di` inside `create` registers an inherited-widget
    // dependency in a callback provider forbids it in (F-0032).
    final flow = FlowScope.of(context).container;
    return BlocProvider(
      create: (_) => flow<CharactersListBloc>(),
      child: const _CharactersListPageContent(),
    );
  }
}

/// Maps each bloc state to UI.
class _CharactersListPageContent extends StatelessWidget {
  const _CharactersListPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = CharactersListL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    final bloc = context.read<CharactersListBloc>();
    void retry() => bloc.add(const CharactersListEvent.retry());
    return Scaffold(
      appBar: AppBar(title: Text(l10n.charactersListTitle)),
      body: BlocBuilder<CharactersListBloc, CharactersListState>(
        builder: (context, state) => state.when(
          loading: () => McLoading(semanticLabel: l10n.charactersListLoading),
          failure: (error, _) => McErrorView(
            title: l10n.charactersListErrorTitle,
            message: failureMessage(error, core),
            retryLabel: core.commonRetry,
            onRetry: retry,
          ),
          success: (page) => McPagedGrid<Character>(
            key: charactersGridKey,
            state: page,
            cellHeight: (width, textScaler) =>
                McMediaCard.heightFor(width: width, textScaler: textScaler),
            itemBuilder: (context, character, _) =>
                CharacterTile(character: character),
            onLoadMore: () => bloc.add(const CharactersListEvent.loadMore()),
            onRetry: retry,
            onRefresh: () {
              final done = Completer<void>();
              bloc.add(CharactersListEvent.refresh(done));
              return done.future;
            },
            emptyTitle: l10n.charactersListEmptyTitle,
            emptyMessage: l10n.charactersListEmptyMessage,
            errorTitle: l10n.charactersListErrorTitle,
            footerErrorMessage: l10n.charactersListLoadMoreFailed,
            retryLabel: core.commonRetry,
            loadingLabel: l10n.charactersListLoading,
          ),
        ),
      ),
    );
  }
}
