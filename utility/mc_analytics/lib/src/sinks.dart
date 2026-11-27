import 'dart:async';

import 'package:mc_analytics/src/records.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The event the kit emits for `Analytics.screen`; its `screen_name` param
/// is the screen.
const String screenViewEventName = 'mc_screen_view';

/// The event the kit emits when a session begins; its `reason` param is
/// `cold_start`, `timeout` or `reset`.
const String sessionStartEventName = 'mc_session_start';

/// Where delivered entries go. Only `Analytics` calls it, and only while
/// consent is granted. A sink that throws is skipped for that entry and
/// reported once; it never breaks the app or the other sinks.
///
/// There is no network sink: P-004 needs the Product Owner's sign-off first.
abstract interface class AnalyticsSink {
  void record(AnalyticsRecord record);
}

/// Keeps delivered entries in order, for tests and the BDD steps.
class InMemoryAnalyticsSink implements AnalyticsSink {
  final List<AnalyticsRecord> _records = <AnalyticsRecord>[];

  List<AnalyticsRecord> get records => List.unmodifiable(_records);

  /// Delivered events (screen views and session starts included), in order.
  List<AnalyticsEventRecord> get events =>
      List.unmodifiable(_records.whereType<AnalyticsEventRecord>());

  /// The screens tracked, in order: the `screen_name` of each
  /// `mc_screen_view`.
  List<String> get screens => [
    for (final e in events)
      if (e.name == screenViewEventName) e.params['screen_name']! as String,
  ];

  void clear() => _records.clear();

  @override
  void record(AnalyticsRecord record) => _records.add(record);
}

/// Forwards delivered entries to `mc_monitoring` as `EventEntry`, so a dev
/// build shows them in its log. The attributes are the event's params plus
/// `session_id` and `seq`. A user property is the event `user_property` with
/// `key` and `value`.
class MonitoringAnalyticsSink implements AnalyticsSink {
  MonitoringAnalyticsSink(this._monitoring);

  final Monitoring _monitoring;

  @override
  void record(AnalyticsRecord record) {
    final (name, attributes) = switch (record) {
      AnalyticsEventRecord(:final name, :final params) => (name, params),
      AnalyticsUserPropertyRecord(:final key, :final value) => (
        'user_property',
        <String, Object>{'key': key, 'value': value},
      ),
    };
    unawaited(
      _monitoring.trackEvent(
        name,
        attributes: {
          ...attributes,
          'session_id': record.sessionId,
          'seq': record.seq,
        },
      ),
    );
  }
}
