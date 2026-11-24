import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Holds deep links until boot is ready (R29, plan 01 §3.4 step 1).
///
/// Register it with [install] **before** `runApp`, so it is the first
/// observer: while attached it consumes every pushed route (returns `true`),
/// and no other observer, such as the boot `MaterialApp`'s navigator, sees
/// the link. It records the cold-start link from
/// `PlatformDispatcher.defaultRouteName` too. On `ready`, `McApp` calls
/// [take] once for the router's `initialLocation` and then [detach]es it, so
/// later links go to go_router.
class PendingLinks extends WidgetsBindingObserver {
  PendingLinks._(this._binding, String? coldStart)
    : _latest = coldStart == null ? null : normalise(coldStart);

  /// Records the cold-start link and registers the holder as an observer.
  static PendingLinks install(WidgetsBinding binding) {
    final links = PendingLinks._(binding, _coldStart(binding));
    binding.addObserver(links);
    return links;
  }

  final WidgetsBinding _binding;
  String? _latest;
  bool _attached = true;

  /// Links received through `didPushRouteInformation` while attached.
  int get received => _received;
  int _received = 0;

  /// How often [take] was called. `McApp` calls it once, on `ready`.
  int get takes => _takes;
  int _takes = 0;

  /// The newest held location, or null.
  String? get pending => _latest;

  bool get isAttached => _attached;

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    if (!_attached) {
      return SynchronousFuture<bool>(false);
    }
    _received++;
    _latest = normalise(routeInformation.uri.toString());
    return SynchronousFuture<bool>(true);
  }

  /// The held location (newest wins), or `/`, and clears it.
  String take() {
    _takes++;
    final location = _latest ?? '/';
    _latest = null;
    return location;
  }

  /// Stops holding links. Safe to call more than once.
  void detach() {
    if (_attached) {
      _attached = false;
      _binding.removeObserver(this);
    }
  }

  static String? _coldStart(WidgetsBinding binding) {
    final name = binding.platformDispatcher.defaultRouteName;
    return name == '/' || name.isEmpty ? null : name;
  }

  /// `miniclient://app/placeholder/7?x=1` → `/placeholder/7?x=1`; a plain
  /// path is kept. The host (`app`) only marks the app's own links.
  static String normalise(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      return '/';
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '${path.startsWith('/') ? path : '/$path'}$query$fragment';
  }
}
