import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:comics_details/src/presentation/bloc/comic_details_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Key of the creators section, for tests.
const comicCreditsKey = ValueKey<String>('comics_details.creators');

/// The creators section: every credit with its role, in the contract's role
/// order. A tap hands the creator over to the app (through the bloc).
class ComicCredits extends StatelessWidget {
  const ComicCredits({required this.credits, super.key});

  final List<Credit> credits;

  @override
  Widget build(BuildContext context) => Column(
    key: comicCreditsKey,
    children: [for (final credit in credits) _CreditRow(credit: credit)],
  );
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final Credit credit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        onTap: () => context.read<ComicDetailsBloc>().add(
          ComicDetailsEvent.openCreator(credit.id),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: mcMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McSpacing.lg,
              vertical: McSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(credit.name, style: text.bodyLarge),
                      Text(
                        roleLabel(credit.role, ComicsDetailsL10n.of(context)),
                        style: text.bodySmall?.copyWith(
                          color: context.mcPalette.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const McGap.sm(),
                Icon(
                  Icons.chevron_right,
                  color: context.mcPalette.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A role as the user reads it.
String roleLabel(CreatorRole role, ComicsDetailsL10n l10n) => switch (role) {
  CreatorRole.writer => l10n.comicsDetailsRoleWriter,
  CreatorRole.penciller => l10n.comicsDetailsRolePenciller,
  CreatorRole.inker => l10n.comicsDetailsRoleInker,
  CreatorRole.colorist => l10n.comicsDetailsRoleColorist,
  CreatorRole.letterer => l10n.comicsDetailsRoleLetterer,
  CreatorRole.coverArtist => l10n.comicsDetailsRoleCoverArtist,
};
