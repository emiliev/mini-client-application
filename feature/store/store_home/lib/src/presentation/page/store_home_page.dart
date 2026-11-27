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
///   and states. The visit's start reads every bloc (creating it) and adds
///   its `load`, so every section loads in parallel, also those below the
///   fold, which a lazy list has not built yet (F-0040 fact 6).
/// - **The flag decides which sections exist**, read once when the page
///   opens: with `store.home_featured` off, the featured section and its bloc
///   are never created, so its endpoint is never called.
/// - **A visit starts when the page is shown** (F-0056 §1): the blocs exist
///   but stay idle while the page is built under another screen (the store
///   below a cold `/store/categories/:id` link). The first time the page is
///   the flow's top page and the flow's route is the app's current route,
///   every section loads, once; the visit lasts as long as the page, so a
///   comic opened and closed over the store loads and tracks nothing again.
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
        BlocProvider(create: (c) => c.di<BannersBloc>()),
        BlocProvider(create: (c) => c.di<DealsBloc>()),
        BlocProvider(create: (c) => c.di<CategoriesBloc>()),
        if (_featured) BlocProvider(create: (c) => c.di<FeaturedBloc>()),
        BlocProvider(create: (c) => c.di<CartSummaryBloc>()),
      ],
      child: _StoreHomeContent(featured: _featured),
    );
  }
}

class _StoreHomeContent extends StatefulWidget {
  const _StoreHomeContent({required this.featured});

  final bool featured;

  @override
  State<_StoreHomeContent> createState() => _StoreHomeContentState();
}

class _StoreHomeContentState extends State<_StoreHomeContent> {
  bool _started = false;

  bool get featured => widget.featured;

  /// Depends on the flow's scope, so it runs again when whether the flow is
  /// visible in the app changes (`FlowScope.outerIsCurrent`: its own route,
  /// and every flow around it). The store page is always its flow's first
  /// page when it is built (the category page only ever opens above it), so
  /// its own flow page needs no check.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = FlowScope.maybeOf(context)?.outerIsCurrent ?? true;
    if (shown && !_started) {
      _started = true;
      _startAll(context);
    }
  }

  /// The visit starts: every section loads at once, each on its own.
  void _startAll(BuildContext context) {
    context.read<BannersBloc>().add(const BannersEvent.load());
    context.read<DealsBloc>().add(const DealsEvent.load());
    context.read<CategoriesBloc>().add(const CategoriesEvent.load());
    if (featured) {
      context.read<FeaturedBloc>().add(const FeaturedEvent.load());
    }
    context.read<CartSummaryBloc>().add(const CartSummaryEvent.load());
  }

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
        (d) => context.read<CartSummaryBloc>().add(CartSummaryEvent.refresh(d)),
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
