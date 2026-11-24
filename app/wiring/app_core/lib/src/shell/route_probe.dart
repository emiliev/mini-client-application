import 'package:flutter/widgets.dart';

/// Counts route builds and `redirect` calls, and how many happened before
/// boot was ready (R29: there must be none). Tests pass one to `McApp`;
/// production passes none, and [record] / [recordRedirect] do nothing.
class McRouteProbe {
  /// Route names in build order.
  final List<String> builds = <String>[];

  /// Locations `redirect` was asked about, in order.
  final List<String> redirects = <String>[];

  /// Builds and redirects that happened before [markReady].
  int get beforeReady => _beforeReady;
  int _beforeReady = 0;

  bool get isReady => _ready;
  bool _ready = false;

  /// `McApp` calls this on `ready`, before it creates the router.
  void markReady() => _ready = true;

  void _count() {
    if (!_ready) {
      _beforeReady++;
    }
  }

  /// Called from a route's `build`.
  static void record(BuildContext context, String route) {
    final probe = _maybeOf(context);
    if (probe != null) {
      probe._count();
      probe.builds.add(route);
    }
  }

  /// Called from the router's top-level `redirect`.
  static void recordRedirect(BuildContext context, Uri location) {
    final probe = _maybeOf(context);
    if (probe != null) {
      probe._count();
      probe.redirects.add(location.toString());
    }
  }

  static McRouteProbe? _maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<McRouteProbeScope>()?.probe;
}

/// Puts a [McRouteProbe] above the app. `McApp` adds it when given a probe.
class McRouteProbeScope extends InheritedWidget {
  const McRouteProbeScope({
    required this.probe,
    required super.child,
    super.key,
  });

  final McRouteProbe probe;

  @override
  bool updateShouldNotify(McRouteProbeScope oldWidget) =>
      !identical(probe, oldWidget.probe);
}
