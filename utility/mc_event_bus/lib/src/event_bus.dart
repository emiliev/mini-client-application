import 'dart:async';

/// Base type of everything published on the [EventBus].
abstract class BusEvent {
  const BusEvent();
}

/// Data under [topic] changed; listeners should refresh.
class DataChanged extends BusEvent {
  const DataChanged(this.topic);
  final String topic;

  @override
  bool operator ==(Object other) =>
      other is DataChanged && other.topic == topic;

  @override
  int get hashCode => Object.hash(DataChanged, topic);
}

/// Typed in-process publish and subscribe. Delivery is synchronous, so each
/// subscriber sees each event exactly once, in publish order.
class EventBus {
  final StreamController<BusEvent> _controller =
      StreamController<BusEvent>.broadcast(sync: true);

  void publish(BusEvent event) => _controller.add(event);

  /// Events of type [T]. Cancel the subscription to stop receiving.
  Stream<T> on<T extends BusEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  /// [DataChanged] events for [topic] only.
  Stream<DataChanged> onDataChanged(String topic) =>
      on<DataChanged>().where((e) => e.topic == topic);

  Future<void> dispose() => _controller.close();
}
