/// The port a bloc tracks product analytics through (T-0056).
///
/// Blocs are read by code generators, so they import no Flutter (R15), and
/// `mc_analytics` is a Flutter package (its route and lifecycle observers).
/// This interface is the pure-Dart side of it: `mc_analytics`' `Analytics`
/// implements it and `AnalyticsDIInitializer` registers it, so a bloc takes
/// an `AnalyticsTracker` in its constructor (a `RootImport<AnalyticsTracker>`
/// of its flow) and the consent gate, validation and sessions still apply.
///
/// It lives here because every bloc already depends on `mc_monitoring`
/// (`McBloc` reports through it), so neither kit gains a dependency.
abstract interface class AnalyticsTracker {
  /// Tracks the event [name] (snake_case) with [params], whose values are
  /// `String`, `int`, `double` or `bool` (`mc_analytics`' `AnalyticsRules`).
  void trackEvent(String name, [Map<String, Object> params = const {}]);
}
