import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/presentation/bloc/featured_bloc.dart';
import 'package:store_home/src/presentation/widget/store_section.dart';

/// The featured products: a horizontal carousel of `McMediaCard`s with the
/// price the cart charges. Built only while `store.home_featured` is on.
class FeaturedSection extends StatelessWidget {
  const FeaturedSection({super.key});

  static const _section = StoreSection.featured;
  static const double _cardWidth = 140;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final height = McMediaCard.heightFor(
      width: _cardWidth,
      textScaler: MediaQuery.textScalerOf(context),
    );
    return StoreSectionFrame(
      section: _section,
      title: l10n.storeHomeFeatured,
      child: BlocBuilder<FeaturedBloc, FeaturedState>(
        builder: (context, state) => state.when(
          loading: () => SectionSkeleton(
            section: _section,
            label: l10n.storeHomeSectionLoading(l10n.storeHomeFeatured),
            height: height,
            itemWidth: _cardWidth,
          ),
          empty: () => SectionEmpty(
            section: _section,
            message: l10n.storeHomeFeaturedEmpty,
          ),
          failure: (error, _) => SectionError(
            section: _section,
            title: l10n.storeHomeFeaturedError,
            error: error,
            onRetry: () =>
                context.read<FeaturedBloc>().add(const FeaturedEvent.retry()),
          ),
          ready: (products) => SectionCarousel(
            section: _section,
            height: height,
            itemWidth: _cardWidth,
            count: products.length,
            itemBuilder: (context, i) => _ProductCard(product: products[i]),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) => McMediaCard(
    key: ValueKey('store_home.featured.${product.id.value}'),
    title: product.title,
    image: product.cover,
    subtitle: formatMoney(
      product.dealPrice ?? product.price,
      Localizations.localeOf(context).toString(),
    ),
    onTap: () =>
        context.read<FeaturedBloc>().add(FeaturedEvent.open(product)),
  );
}
