import 'dart:math';

import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Lets queued microtasks run (delivery is a microtask later). No timer.
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.value();
  }
}

/// An [Analytics] over fakes: an in-memory sink, an in-memory monitoring
/// sink, a clock the test moves and a seeded random.
class Rig {
  Rig({
    AnalyticsConsent consent = AnalyticsConsent.granted,
    bool debugMode = true,
    ConsentPersister? persist,
    List<AnalyticsSink> extraSinks = const [],
    bool forwardToMonitoring = false,
    int seed = 1,
  }) : random = Random(seed) {
    monitoring = Monitoring([monitoringSink]);
    analytics = Analytics(
      sinks: [
        sink,
        if (forwardToMonitoring) MonitoringAnalyticsSink(monitoring),
        ...extraSinks,
      ],
      monitoring: monitoring,
      consent: consent,
      persist: persist,
      random: random,
      clock: () => now,
      debugMode: debugMode,
    );
  }

  final InMemoryAnalyticsSink sink = InMemoryAnalyticsSink();
  final InMemorySink monitoringSink = InMemorySink();
  late final Monitoring monitoring;
  late final Analytics analytics;
  final Random random;
  DateTime now = DateTime.utc(2026, 11, 27, 9);

  /// The delivered events' names, in order, without the kit's session starts.
  List<String> get names => [
    for (final e in sink.events)
      if (e.name != sessionStartEventName) e.name,
  ];

  List<ErrorEntry> get errors =>
      monitoringSink.entries.whereType<ErrorEntry>().toList();

  List<EventEntry> get monitoringEvents =>
      monitoringSink.entries.whereType<EventEntry>().toList();
}

/// A sink that throws on every record.
class ThrowingSink implements AnalyticsSink {
  int calls = 0;

  @override
  void record(AnalyticsRecord record) {
    calls++;
    throw StateError('sink failed');
  }
}

/// A sink that runs [onRecord] for each record, and keeps them.
class HookSink implements AnalyticsSink {
  HookSink(this.onRecord);

  final void Function(AnalyticsRecord record) onRecord;
  final List<AnalyticsRecord> records = [];

  @override
  void record(AnalyticsRecord record) {
    records.add(record);
    onRecord(record);
  }
}
