import 'package:commerce_wiring/src/flows/cart_placeholder_flow.dart';
import 'package:commerce_wiring/src/routes/route_targets.dart';
import 'package:store_home/store_home.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class CommerceRouteTargetsImpl implements CommerceRouteTargets {
  const CommerceRouteTargetsImpl({
    required StoreHomeNavigator storeHome,
    required DateTime Function() clock,
  }) : _storeHome = storeHome,
       _clock = clock;

  final StoreHomeNavigator _storeHome;
  final DateTime Function() _clock;

  @override
  StoreHomeFlow store({String? category}) => StoreHomeFlow(
    navigator: _storeHome,
    clock: _clock,
    initialCategory: category == null ? null : CategoryId(category),
  );

  @override
  CartPlaceholderFlow cart() => const CartPlaceholderFlow();
}
