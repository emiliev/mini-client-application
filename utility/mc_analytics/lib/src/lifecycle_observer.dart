import 'package:flutter/widgets.dart';
import 'package:mc_analytics/src/analytics.dart';

/// Tells [Analytics] when the app goes to the background and comes back, so a
/// session can end after 30 minutes away. `inactive` (a call, the app
/// switcher) is neither.
class AnalyticsLifecycleObserver with WidgetsBindingObserver {
  AnalyticsLifecycleObserver(this._analytics);

  final Analytics _analytics;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _analytics.appForegrounded();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _analytics.appBackgrounded();
      case AppLifecycleState.inactive:
        break;
    }
  }
}
