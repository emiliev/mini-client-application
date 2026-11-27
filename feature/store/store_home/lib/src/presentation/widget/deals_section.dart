import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_media/mc_media.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/presentation/bloc/deals_bloc.dart';
import 'package:store_home/src/presentation/widget/store_section.dart';

/// The deals: a horizontal carousel of cards with the discount, the deal
/// price, the original price struck through, and how long the deal runs.
class DealsSection extends StatelessWidget {
  const DealsSection({super.key});

  static const _section = StoreSection.deals;
  static const double _cardWidth = 156;
  static const double _imageAspectRatio = 0.8;

  /// Title (2 lines), deal price, original price, "ends in": every line is
  /// measured at the text scale, so nothing overflows at 2x.
  static double _cardHeight(BuildContext context) =>
      (_cardWidth / _imageAspectRatio +
              2 * McSpacing.sm +
              scaledLines(context, SectionType.title, 3) +
              2 * scaledLines(context, SectionType.detail, 1) +
              2 * McSpacing.xxs)
          .ceilToDouble() +
      1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final height = _cardHeight(context);
    return StoreSectionFrame(
      section: _section,
      title: l10n.storeHomeDeals,
      child: BlocBuilder<DealsBloc, DealsState>(
        builder: (context, state) => state.when(
          loading: () => SectionSkeleton(
            section: _section,
            label: l10n.storeHomeSectionLoading(l10n.storeHomeDeals),
            height: height,
            itemWidth: _cardWidth,
          ),
          empty: () =>
              SectionEmpty(section: _section, message: l10n.storeHomeDealsEmpty),
          failure: (error, _) => SectionError(
            section: _section,
            title: l10n.storeHomeDealsError,
            error: error,
            onRetry: () =>
                context.read<DealsBloc>().add(const DealsEvent.retry()),
          ),
          ready: (deals, now) => SectionCarousel(
            section: _section,
            height: height,
            itemWidth: _cardWidth,
            count: deals.length,
            itemBuilder: (context, i) => _DealCard(deal: deals[i], now: now),
          ),
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.now});

  final Deal deal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final price = formatMoney(deal.dealPrice, locale);
    final original = formatMoney(deal.originalPrice, locale);
    final endsIn = l10n.storeHomeDealEndsIn(deal.daysLeftAt(now));
    final discount = l10n.storeHomeDealDiscount(deal.discountPercent);
    void open() => context.read<DealsBloc>().add(DealsEvent.open(deal));
    return Semantics(
      key: ValueKey('store_home.deal.${deal.product.id.value}'),
      button: true,
      container: true,
      label: deal.product.title,
      value: '$discount, ${l10n.storeHomeDealPrices(original, price)}, '
          '$endsIn',
      onTap: open,
      child: ExcludeSemantics(
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: McRadius.mdAll,
            side: BorderSide(color: p.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: DealsSection._imageAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      McImage(
                        image: deal.product.cover,
                        variant: ImageVariant.portraitLarge,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      PositionedDirectional(
                        top: McSpacing.sm,
                        start: McSpacing.sm,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.error,
                            borderRadius: McRadius.smAll,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: McSpacing.xs,
                              vertical: McSpacing.xxs,
                            ),
                            child: Text(
                              discount,
                              style: text.labelLarge?.copyWith(
                                color: p.onError,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(McSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deal.product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge,
                      ),
                      Text(
                        price,
                        key: ValueKey(
                          'store_home.deal.${deal.product.id.value}.price',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(color: p.primary),
                      ),
                      const SizedBox(height: McSpacing.xxs),
                      Text(
                        original,
                        key: ValueKey(
                          'store_home.deal.${deal.product.id.value}.original',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: McSpacing.xxs),
                      Text(
                        endsIn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
