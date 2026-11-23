enum LogLevel { debug, info, warning, error }

/// One recorded monitoring call.
sealed class MonitoringEntry {
  const MonitoringEntry();
}

class LogEntry extends MonitoringEntry {
  const LogEntry(this.level, this.message);
  final LogLevel level;
  final String message;
}

class EventEntry extends MonitoringEntry {
  const EventEntry(this.name, this.attributes);
  final String name;
  final Map<String, Object?> attributes;
}

class ErrorEntry extends MonitoringEntry {
  const ErrorEntry(this.error, this.stackTrace, {required this.fatal});
  final Object error;
  final StackTrace? stackTrace;
  final bool fatal;
}

/// Receives every monitoring call.
abstract class MonitoringSink {
  void record(MonitoringEntry entry);
}

/// Prints entries through [printer] (defaults to `print`).
class ConsoleSink implements MonitoringSink {
  ConsoleSink({void Function(String line)? printer})
    : _printer = printer ?? print;

  final void Function(String line) _printer;

  @override
  void record(MonitoringEntry entry) => _printer(switch (entry) {
    LogEntry(:final level, :final message) => '[${level.name}] $message',
    EventEntry(:final name, :final attributes) => '[event] $name $attributes',
    ErrorEntry(:final error, :final stackTrace, :final fatal) =>
      '[error${fatal ? ' fatal' : ''}] $error${stackTrace == null ? '' : '\n$stackTrace'}',
  });
}

/// Keeps entries in order, for tests and e2e inspection.
class InMemorySink implements MonitoringSink {
  final List<MonitoringEntry> _entries = <MonitoringEntry>[];

  List<MonitoringEntry> get entries => List.unmodifiable(_entries);

  void clear() => _entries.clear();

  @override
  void record(MonitoringEntry entry) => _entries.add(entry);
}
