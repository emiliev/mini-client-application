import 'dart:async';

import 'package:app_core/src/boot/boot_state.dart';
import 'package:flutter/foundation.dart';

/// Runs root DI initialisation once. Usually
/// `() => initializeDIContainer(rootInitializers(...))`.
typedef BootTask = Future<void> Function();

/// The default boot timeout (T-0021-AC2).
const Duration defaultBootTimeout = Duration(seconds: 10);

/// Boot with an error state, a timeout and Retry (D-21, fixes P-028).
///
/// - [start] runs [task] and moves to [BootReady] or [BootFailed]. If the task
///   has not finished after [timeout], the state becomes [BootTimedOut].
/// - [retry] after a failure runs [task] again. After a timeout it waits for
///   the same, still-running task with a fresh timeout, because the root
///   container accepts one initialisation at a time; a task that finished
///   while the timeout screen showed is picked up at once.
/// - A result that arrives for an attempt that is no longer current (it timed
///   out) does not change the state by itself (attempt counter).
///
/// This is a plain `ChangeNotifier` until `mc_bloc_kit`'s `McBloc` exists
/// (T-0022); the public surface (`state`, `start`, `retry`) stays the same.
class BootBloc extends ChangeNotifier {
  BootBloc({required BootTask task, this.timeout = defaultBootTimeout})
    : _task = task;

  final BootTask _task;
  final Duration timeout;

  BootState _state = const BootBooting(0);
  int _attempt = 0;
  _Run? _run;
  Timer? _timer;
  bool _disposed = false;

  BootState get state => _state;

  /// How many times [task] was started (a retry after a timeout reuses the
  /// running task, so it does not count).
  int get taskRuns => _taskRuns;
  int _taskRuns = 0;

  /// Starts the first attempt. Does nothing once booting or ready.
  void start() {
    if (_attempt > 0) {
      return;
    }
    _begin();
  }

  /// Starts the next attempt from [BootFailed] or [BootTimedOut].
  void retry() {
    if (_state is BootFailed || _state is BootTimedOut) {
      _begin();
    }
  }

  void _begin() {
    final attempt = ++_attempt;
    _emit(BootBooting(attempt));
    final run = _run ??= _startRun();
    _timer?.cancel();
    _timer = Timer(timeout, () {
      if (_isCurrent(attempt)) {
        _emit(BootTimedOut(attempt, timeout));
      }
    });
    run.future.then(
      (_) {
        if (_isCurrent(attempt)) {
          _timer?.cancel();
          _emit(const BootReady());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isCurrent(attempt)) {
          _timer?.cancel();
          _emit(BootFailed(attempt, error, stackTrace));
        }
      },
    );
  }

  _Run _startRun() {
    _taskRuns++;
    final run = _Run(Future<void>.sync(_task));
    // A failed run is discarded, so the next attempt starts a fresh one.
    run.future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_run, run)) {
          _run = null;
        }
      },
    );
    return run;
  }

  bool _isCurrent(int attempt) =>
      !_disposed && attempt == _attempt && _state is BootBooting;

  void _emit(BootState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

class _Run {
  _Run(this.future);

  final Future<void> future;
}
