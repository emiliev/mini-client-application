import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_formatters/mc_formatters.dart';

/// Key of the facts section, for tests.
const comicFactsKey = ValueKey<String>('comics_details.facts');

/// The facts section: issue, price, pages and release day, each formatted
/// for the current locale (`mc_formatters`).
class ComicFacts extends StatelessWidget {
  const ComicFacts({required this.comic, super.key});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final l10n = ComicsDetailsL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final facts = [
      (
        l10n.comicsDetailsFactIssue,
        l10n.comicsDetailsFactIssueValue(comic.issueNumber),
      ),
      (l10n.comicsDetailsFactPrice, formatMoney(comic.price, locale)),
      (l10n.comicsDetailsFactPages, formatNumber(comic.pageCount, locale)),
      (
        l10n.comicsDetailsFactReleased,
        formatDate(comic.releaseDate, locale),
      ),
    ];
    return Padding(
      key: comicFactsKey,
      padding: McInsets.horizontal,
      child: Column(
        children: [
          for (final (label, value) in facts)
            _FactRow(label: label, value: value),
        ],
      ),
    );
  }
}

/// One fact: its label on the start side, its value on the end side, read
/// as one sentence by screen readers.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: McSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: context.mcPalette.onSurfaceMuted,
                ),
              ),
            ),
            const McGap.md(),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: text.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
