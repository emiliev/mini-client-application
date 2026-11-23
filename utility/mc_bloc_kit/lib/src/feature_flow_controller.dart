import 'dart:async';

/// The handle a feature's blocs use to drive the flow they live in (Tide's
/// `FeatureFlowController`). Pure Dart: the Flutter side, `mc_feature_flow`,
/// listens to it and builds the pages (R15).
///
/// [T] is the flow state. Screens are an implementation detail of the flow,
/// so [T] describes what is selected, not which page is showing.
class FeatureFlowController<T> {
  FeatureFlowController(T state) : _state = state;

  T _state;
  bool _completed = false;
  Object? _result;
  final StreamController<T> _states = StreamController<T>.broadcast(sync: true);
  final StreamController<Object?> _completions =
      StreamController<Object?>.broadcast(sync: true);

  /// The current flow state.
  T get state => _state;

  /// Emits each state set through [update], synchronously.
  Stream<T> get states => _states.stream;

  /// Emits the result once, when [complete] is first called.
  Stream<Object?> get completions => _completions.stream;

  /// Whether [complete] has been called.
  bool get isCompleted => _completed;

  /// The result passed to [complete]; null before completion.
  Object? get result => _result;

  /// Replaces the state with `change(state)` and notifies [states].
  /// Ignored once the flow is completed.
  void update(T Function(T state) change) {
    if (_completed) {
      return;
    }
    _state = change(_state);
    _states.add(_state);
  }

  /// Records a state that the host changed itself (for example the iOS back
  /// gesture popped a page). Does not notify [states], so the host does not
  /// hear its own change.
  void restore(T state) {
    _state = state;
  }

  /// Finishes the flow. The first call emits [result] on [completions]; later
  /// calls are ignored, so `onComplete` fires exactly once.
  void complete([Object? result]) {
    if (_completed) {
      return;
    }
    _completed = true;
    _result = result;
    _completions.add(result);
  }

  Future<void> dispose() async {
    await _states.close();
    await _completions.close();
  }
}
