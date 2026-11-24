import 'package:mc_monitoring/mc_monitoring.dart';

/// A [Monitoring] that records every call in memory (Tide's `MockMonitoring`).
///
/// Hand-written rather than a mocktail `Mock`: `mocktail` is not in the root
/// lock (F-0024), and recording is what feature tests assert on.
class MockMonitoring extends Monitoring {
  MockMonitoring._(this._sink) : super([_sink]);

  final InMemorySink _sink;

  /// Every entry in call order.
  List<MonitoringEntry> get entries => _sink.entries;

  List<LogEntry> get logs => entries.whereType<LogEntry>().toList();
  List<EventEntry> get events => entries.whereType<EventEntry>().toList();
  List<ErrorEntry> get errors => entries.whereType<ErrorEntry>().toList();

  void clear() => _sink.clear();
}

/// A fresh [MockMonitoring] with no entries.
MockMonitoring createMockMonitoring() => MockMonitoring._(InMemorySink());
