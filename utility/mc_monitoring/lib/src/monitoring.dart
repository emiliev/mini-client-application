import 'package:mc_monitoring/src/sinks.dart';

/// Tide-style monitoring facade. Pure Dart: the Flutter error hooks live in
/// `app_core` and call [recordError] (R15, D-11).
class Monitoring {
  Monitoring(List<MonitoringSink> sinks) : _sinks = List.of(sinks);

  final List<MonitoringSink> _sinks;

  Future<void> log(String message, {LogLevel level = LogLevel.info}) async =>
      _emit(LogEntry(level, message));

  Future<void> trackEvent(
    String name, {
    Map<String, Object?> attributes = const {},
  }) async => _emit(EventEntry(name, Map.unmodifiable(attributes)));

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async => _emit(ErrorEntry(error, stackTrace, fatal: fatal));

  /// Monitoring never throws: a failing sink is skipped so later sinks still
  /// get the entry, and its error is not reported back through monitoring.
  void _emit(MonitoringEntry entry) {
    for (final sink in _sinks) {
      try {
        sink.record(entry);
      } on Object {
        // Deliberately swallowed.
      }
    }
  }
}
