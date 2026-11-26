import 'package:comics_details/comics_details.dart';
import 'package:publishing_wiring/src/flows/creator_details_placeholder_flow.dart';

/// What the publishing group's typed routes build (R15): each member returns
/// a feature's `*Flow`. The route files import only this interface;
/// `PublishingRouteTargetsImpl` (unannotated) supplies the flows' navigators
/// and is registered by `PublishingWiringDIInitializer`.
///
/// Prefixed with the group (universe_wiring's is `RouteTargets`) because the
/// app imports every wiring's barrel side by side.
abstract interface class PublishingRouteTargets {
  /// One comic: `/comics/:id`.
  ComicsDetailsFlow comicDetails(int id);

  /// One creator: `/creators/:id`. A placeholder until `creators_details`
  /// exists.
  CreatorDetailsPlaceholderFlow creatorDetails(int id);
}
