import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:comics_details/src/presentation/bloc/comic_favourite_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// Key of the favourite toggle's inline error, for tests.
const favouriteErrorKey = ValueKey<String>('comics_details.favourite.error');

/// The favourite toggle: a button whose label says what a tap does, and an
/// inline error below it after a failed read or write. A tap dispatches an
/// event; only the bloc decides (sign in first, write, roll back).
class FavouriteToggle extends StatelessWidget {
  const FavouriteToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = ComicsDetailsL10n.of(context);
    return BlocBuilder<ComicFavouriteBloc, ComicFavouriteState>(
      builder: (context, state) {
        void toggle() => context.read<ComicFavouriteBloc>().add(
          const ComicFavouriteEvent.toggle(),
        );
        final (favourite, enabled, error) = state.when(
          loading: () => (false, false, null),
          signingIn: () => (false, false, null),
          ready: (favourite, saving) => (favourite, !saving, null),
          loadFailed: (_, _) => (
            false,
            true,
            l10n.comicsDetailsFavouriteLoadFailed,
          ),
          saveFailed: (_, favourite, _) => (
            favourite,
            true,
            l10n.comicsDetailsFavouriteSaveFailed,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              toggled: favourite,
              child: McButton(
                label: favourite
                    ? l10n.comicsDetailsFavouriteRemove
                    : l10n.comicsDetailsFavouriteAdd,
                variant: favourite
                    ? McButtonVariant.secondary
                    : McButtonVariant.primary,
                onPressed: enabled ? toggle : null,
              ),
            ),
            if (error != null) ...[
              const McGap.xs(),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: favouriteErrorKey,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mcPalette.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
