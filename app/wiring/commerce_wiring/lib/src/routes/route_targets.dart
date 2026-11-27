import 'package:commerce_wiring/src/flows/cart_placeholder_flow.dart';
import 'package:store_home/store_home.dart';

/// What the commerce group's typed routes build (R15): each member returns
/// a feature's `*Flow`. The route files import only this interface;
/// `CommerceRouteTargetsImpl` (unannotated) supplies the flows' navigators
/// and is registered by `CommerceWiringDIInitializer`.
///
/// Prefixed with the group (`UniverseRouteTargets`, ...) because the app
/// imports every wiring's barrel side by side (F-0040 fact 11).
abstract interface class CommerceRouteTargets {
  /// The store home: `/store`; with [category], the flow opened at that
  /// category (`/store/categories/:id`).
  StoreHomeFlow store({String? category});

  /// The cart: `/store/cart`. A placeholder until the cart feature exists.
  CartPlaceholderFlow cart();
}
