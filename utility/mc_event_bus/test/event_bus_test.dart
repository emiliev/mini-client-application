import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:test/test.dart';

void main() {
  test(
    'T-0020-AC3 two subscribers each receive the event exactly once',
    () async {
      final bus = EventBus();
      final a = <DataChanged>[];
      final b = <DataChanged>[];
      final subA = bus.onDataChanged('favourites').listen(a.add);
      final subB = bus.onDataChanged('favourites').listen(b.add);

      bus.publish(const DataChanged('favourites'));
      bus.publish(const DataChanged('cart'));
      await Future<void>.delayed(Duration.zero);

      expect(a, [const DataChanged('favourites')]);
      expect(b, [const DataChanged('favourites')]);
      await subA.cancel();
      await subB.cancel();
      await bus.dispose();
    },
  );

  test('T-0020-AC3 an unsubscribed listener receives nothing', () async {
    final bus = EventBus();
    final received = <DataChanged>[];
    final sub = bus.onDataChanged('favourites').listen(received.add);
    await sub.cancel();

    bus.publish(const DataChanged('favourites'));
    await Future<void>.delayed(Duration.zero);

    expect(received, isEmpty);
    await bus.dispose();
  });

  test('T-0020-AC3 a listener may publish from inside its callback', () async {
    final bus = EventBus();
    final seen = <String>[];
    final sub = bus.on<DataChanged>().listen((e) {
      seen.add(e.topic);
      if (e.topic == 'a') {
        bus.publish(const DataChanged('b'));
      }
    });

    bus.publish(const DataChanged('a'));
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['a', 'b']);
    await sub.cancel();
    await bus.dispose();
  });

  test('T-0020-AC3 publish after dispose is a no-op', () async {
    final bus = EventBus();
    await bus.dispose();
    expect(() => bus.publish(const DataChanged('favourites')), returnsNormally);
  });
}
