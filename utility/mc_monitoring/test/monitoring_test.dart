import 'package:get_it/get_it.dart';
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
  // T-0056 closed this package's pre-existing coverage gap (73 % → 100 %):
  // the DI initializer and the console lines of events and errors.
  test('T-0056-AC8 MonitoringDIInitializer registers Monitoring over the '
      'given sinks, and over the console by default', () async {
    final sink = InMemorySink();
    final getIt = GetIt.asNewInstance();
    await MonitoringDIInitializer(sinks: [sink]).init(getIt);
    await getIt<Monitoring>().log('hello');
    expect(sink.entries.single, isA<LogEntry>());

    final defaults = GetIt.asNewInstance();
    await MonitoringDIInitializer().init(defaults);
    expect(defaults<Monitoring>(), isA<Monitoring>());
  });

  test('T-0056-AC8 the console prints events and errors, fatal and with a '
      'stack', () async {
    final lines = <String>[];
    final console = ConsoleSink(printer: lines.add);
    final monitoring = Monitoring([console]);
    await monitoring.trackEvent('opened', attributes: {'id': 1});
    await monitoring.recordError('boom', null, fatal: true);
    await monitoring.recordError('bang', StackTrace.fromString('frame 1'));
    expect(lines, [
      '[event] opened {id: 1}',
      '[error fatal] boom',
      '[error] bang\nframe 1',
    ]);
  });
}

class _ThrowingSink implements MonitoringSink {
  @override
  void record(MonitoringEntry entry) => throw StateError('sink down');
}
