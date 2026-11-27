import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:store_home/src/flags/store_home_flags.dart';
import 'package:store_home/src/presentation/bloc/banners_bloc.dart';
import 'package:store_home/src/presentation/bloc/cart_summary_bloc.dart';
import 'package:store_home/src/presentation/bloc/categories_bloc.dart';
import 'package:store_home/src/presentation/bloc/deals_bloc.dart';
import 'package:store_home/src/presentation/bloc/featured_bloc.dart';
import 'package:store_home/src/presentation/widget/banners_section.dart';
import 'package:store_home/src/presentation/widget/cart_section.dart';
import 'package:store_home/src/presentation/widget/categories_section.dart';
import 'package:store_home/src/presentation/widget/deals_section.dart';
import 'package:store_home/src/presentation/widget/featured_section.dart';
import 'package:store_home/src/presentation/widget/store_section.dart';

/// Key of the store home's scrolling body, for tests.
const storeHomeBodyKey = ValueKey<String>('store_home.body');

/// The store home: provides one bloc per section and nothing else (Tide).
///
/// - **Sections are independent.** Each section has its own bloc, request
///   and states. The blocs are created at once (`lazy: false`), so every
///   section loads in parallel when the page opens, also those below the
///   fold, which a lazy list has not built yet (F-0040 fact 6).
/// - **The flag decides which sections exist**, read once when the page
///   opens: with `store.home_featured` off, the featured section and its bloc
///   are never created, so its endpoint is never called.
class StoreHomePage extends StatefulWidget {
  const StoreHomePage({super.key});

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  /// Read once per visit: a section does not come and go under the reader
  /// when the remote flags arrive.
  late final bool _featured = context.di<FeatureFlagsReader>().value(
    storeHomeFeatured,
  );

  @override
  Widget build(BuildContext context) {
    // The only DI lookups in UI code (R17).
    return MultiBlocProvider(
      providers: [
        BlocProvider(lazy: false, create: (c) => c.di<BannersBloc>()),
        BlocProvider(lazy: false, create: (c) => c.di<DealsBloc>()),
        BlocProvider(lazy: false, create: (c) => c.di<CategoriesBloc>()),
        if (_featured)
          BlocProvider(lazy: false, create: (c) => c.di<FeaturedBloc>()),
        BlocProvider(lazy: false, create: (c) => c.di<CartSummaryBloc>()),
      ],
      child: _StoreHomeContent(featured: _featured),
    );
  }
}

class _StoreHomeContent extends StatelessWidget {
  const _StoreHomeContent({required this.featured});

  final bool featured;

  /// Pull to refresh: every section reloads at once, each on its own; the
  /// control closes when all of them have their answers.
  Future<void> _refreshAll(BuildContext context) {
    Future<void> one(void Function(Completer<void> done) add) {
      final done = Completer<void>();
      add(done);
      return done.future;
    }

    return Future.wait([
      one((d) => context.read<BannersBloc>().add(BannersEvent.refresh(d))),
      one((d) => context.read<DealsBloc>().add(DealsEvent.refresh(d))),
      one(
        (d) => context.read<CategoriesBloc>().add(CategoriesEvent.refresh(d)),
      ),
      if (featured)
        one((d) => context.read<FeaturedBloc>().add(FeaturedEvent.refresh(d))),
      one(
        (d) =>
            context.read<CartSummaryBloc>().add(CartSummaryEvent.refresh(d)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.storeHomeTitle,
      ),
      body: CustomScrollView(
        key: storeHomeBodyKey,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _refreshAll(context)),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: McSpacing.xl),
            sliver: SliverList.list(
              children: [
                const BannersSection(),
                const DealsSection(),
                const CategoriesSection(),
                if (featured) const FeaturedSection(),
                const CartSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
