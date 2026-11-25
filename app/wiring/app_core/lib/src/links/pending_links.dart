import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The deep-link scheme and host an app answers to: `scheme://host/path`.
/// Anything else is not the app's (a cold-start link and a link after boot
/// are treated alike).
class LinkScheme {
  const LinkScheme(this.scheme, this.host);

  /// The main app: `miniclient://app/…`.
  static const LinkScheme app = LinkScheme('miniclient', 'app');

  final String scheme;
  final String host;

  /// Whether [uri] names another scheme or host (a plain path is ours).
  bool isForeign(Uri uri) =>
      uri.hasScheme && (uri.scheme != scheme || uri.host != host);
}

/// Holds deep links until boot is ready (R29, plan 01 §3.4 step 1).
///
/// Register it with [install] **before** `runApp`, so it is the first
/// observer: while attached it consumes every pushed route (returns `true`),
/// and no other observer, such as the boot `MaterialApp`'s navigator, sees
/// the link. It records the cold-start link from
/// `PlatformDispatcher.defaultRouteName` too. On `ready`, `McApp` calls
/// [take] once for the router's `initialLocation`; after the router's first
/// frame it [drain]s a link caught in between and [detach]es, so later links
/// go to go_router.
class PendingLinks extends WidgetsBindingObserver {
  PendingLinks._(this._binding, this.scheme, String? coldStart)
    : _latest = coldStart == null ? null : normalise(coldStart, scheme: scheme);

  /// Records the cold-start link and registers the holder as an observer.
  /// [scheme] is what the app answers to (a sandbox has its own).
  static PendingLinks install(
    WidgetsBinding binding, {
    LinkScheme scheme = LinkScheme.app,
  }) {
    final links = PendingLinks._(binding, scheme, _coldStart(binding));
    binding.addObserver(links);
    return links;
  }

  final WidgetsBinding _binding;

  /// The scheme and host this app's links must carry.
  final LinkScheme scheme;
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
    _latest = normalise(routeInformation.uri.toString(), scheme: scheme);
    return SynchronousFuture<bool>(true);
  }

  /// Holds [link] as if the platform had pushed it (the e2e start link).
  /// Ignored once detached.
  void offer(String link) {
    if (_attached) {
      _latest = normalise(link, scheme: scheme);
    }
  }

  /// The held location (newest wins), or `/`, and clears it.
  String take() {
    _takes++;
    final location = _latest ?? '/';
    _latest = null;
    return location;
  }

  /// The held location, or null, and clears it (not counted in [takes]).
  String? drain() {
    final location = _latest;
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
  /// path is kept. A link with any other scheme or host than [scheme]'s
  /// (default `miniclient://app`) is not the app's and becomes `/`.
  static String normalise(
    String link, {
    LinkScheme scheme = LinkScheme.app,
  }) {
    final uri = Uri.tryParse(link);
    if (uri == null || scheme.isForeign(uri)) {
      return '/';
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '${path.startsWith('/') ? path : '/$path'}$query$fragment';
  }
}
