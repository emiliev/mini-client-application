abstract class RouteTargets {
  AFlow a();
  Widget page();
  Widget get home;
  CharsPage other({int? id});
}

// A group's own targets, named for the group (T-0041): checked the same way.
abstract interface class GroupRouteTargets {
  AFlow fine();
  Widget groupPage();
}
