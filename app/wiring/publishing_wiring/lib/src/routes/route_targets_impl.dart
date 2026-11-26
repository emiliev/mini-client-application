import 'package:comics_details/comics_details.dart';
import 'package:publishing_wiring/src/flows/creator_details_placeholder_flow.dart';
import 'package:publishing_wiring/src/routes/route_targets.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class PublishingRouteTargetsImpl implements PublishingRouteTargets {
  const PublishingRouteTargetsImpl({
    required ComicsDetailsNavigator comicsDetails,
  }) : _comicsDetails = comicsDetails;

  final ComicsDetailsNavigator _comicsDetails;

  @override
  ComicsDetailsFlow comicDetails(int id) =>
      ComicsDetailsFlow(navigator: _comicsDetails, comicId: ComicId(id));

  @override
  CreatorDetailsPlaceholderFlow creatorDetails(int id) =>
      CreatorDetailsPlaceholderFlow(id: id);
}
