import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:test/test.dart';

void main() {
  test('T-0020-AC2 in-memory sink holds entries in order with levels and '
      'attributes', () async {
    final sink = InMemorySink();
    final monitoring = Monitoring([sink]);
    final trace = StackTrace.current;

    await monitoring.log('hello');
    await monitoring.log('careful', level: LogLevel.warning);
    await monitoring.trackEvent('tap', attributes: {'id': 3});
    await monitoring.recordError('boom', trace, fatal: true);

    final entries = sink.entries;
    expect(entries, hasLength(4));
    expect((entries[0] as LogEntry).level, LogLevel.info);
    expect((entries[0] as LogEntry).message, 'hello');
    expect((entries[1] as LogEntry).level, LogLevel.warning);
    expect((entries[2] as EventEntry).name, 'tap');
    expect((entries[2] as EventEntry).attributes, {'id': 3});
    final error = entries[3] as ErrorEntry;
    expect(error.error, 'boom');
    expect(error.stackTrace, trace);
    expect(error.fatal, isTrue);
  });

  test('T-0020-AC2 console sink prints one line per entry', () async {
    final lines = <String>[];
    final monitoring = Monitoring([ConsoleSink(printer: lines.add)]);
    await monitoring.log('a');
    await monitoring.trackEvent('b');
    expect(lines, ['[info] a', '[event] b {}']);
  });

  test(
    'T-0020-AC2 a throwing sink neither blocks later sinks nor throws',
    () async {
      final sink = InMemorySink();
      final monitoring = Monitoring([_ThrowingSink(), sink]);

      await monitoring.log('a');
      await monitoring.trackEvent('b');
      await monitoring.recordError('c', null);

      expect(sink.entries, hasLength(3));
    },
  );
}

class _ThrowingSink implements MonitoringSink {
  @override
  void record(MonitoringEntry entry) => throw StateError('sink down');
}
