import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:store_home/src/di/di_initializer.dart';
import 'package:store_home/src/di/flow_scope.dart';
import 'package:store_home/src/domain/model/category_id.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/domain/model/store_clock.dart';
import 'package:store_home/src/flow/store_home_flow_state.dart';
import 'package:store_home/src/l10n/store_home_l10n.dart';
import 'package:store_home/src/navigator/store_home_navigator.dart';
import 'package:store_home/src/presentation/page/category_page.dart';
import 'package:store_home/src/presentation/page/store_home_page.dart';

/// The feature's only entry point (R4): the store front in independent
/// sections, whose categories open inside the flow, and whose products,
/// banners and cart leave the feature through [navigator].
///
/// The app builds it from a route (`/store`, or `/store/categories/:id` with
/// [initialCategory], commerce_wiring) with the navigator implementation
/// from its wiring and the backend's [clock]; tests pass a mock and the
/// fixtures' clock. It starts from the id alone (plan 01 §4.4).
///
/// Its two pages are screens: `store_home` and `store_category`, tracked
/// from inside the flow by `AnalyticsFlowObserver` (P-103, F-0056).
///
/// Immutable after creation: the flow reads [navigator] and [clock] once,
/// when its scope opens (`provide:` runs once per flow instance). A
/// different [initialCategory] builds a new flow (its `FeatureFlow` is keyed
/// by it).
class StoreHomeFlow extends StatelessWidget {
  const StoreHomeFlow({
    required this.navigator,
    required this.clock,
    this.initialCategory,
    super.key,
  });

  final StoreHomeNavigator navigator;

  /// The time the deals count down against.
  final DateTime Function() clock;

  /// Opens the flow at this category: its page is the only one, so Back
  /// leaves the flow.
  final CategoryId? initialCategory;

  @override
  Widget build(BuildContext context) => FeatureFlow<StoreHomeFlowState>(
    key: ValueKey(initialCategory),
    flowInitializer: const StoreHomeDIInitializer(),
    rootImports: storeHomeRootImports,
    provide: (scope) => scope
      ..registerSingleton<StoreHomeNavigator>(navigator)
      ..registerSingleton<StoreClock>(StoreClock(clock)),
    localizationsDelegates: const [StoreHomeL10n.delegate],
    // The flow's pages are screens (P-103): resolved inside the flow.
    observers: [
      AnalyticsFlowObserver(
        (context) => context.di<AnalyticsTracker>(),
        // Without a dependency on the host route (F-0056 §4).
        host: (context) => FlowScope.read(context).outerRoute,
      ),
    ],
    state: StoreHomeFlowState(
      rootCategory: switch (initialCategory) {
        final id? => OpenCategory(id: id),
        null => null,
      },
    ),
    onGeneratePages: (state) => [
      if (state.rootCategory case final root?)
        McFlowPage(
          name: storeCategoryScreen,
          arguments: root.id,
          child: CategoryPage(key: ValueKey(root.id), category: root),
        )
      else ...[
        const McFlowPage(name: storeHomeScreen, child: StoreHomePage()),
        if (state.category case final category?)
          McFlowPage(
            name: storeCategoryScreen,
            arguments: category.id,
            child: CategoryPage(
              key: ValueKey(category.id),
              category: category,
            ),
          ),
      ],
    ],
  );
}
