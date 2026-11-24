import 'dart:async';

import 'package:app_core/src/boot/boot_state.dart';
import 'package:bloc/bloc.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';

/// Runs root DI initialisation once. Usually
/// `() => initializeDIContainer(rootInitializers(...))`.
typedef BootTask = Future<void> Function();

/// The default boot timeout (T-0021-AC2).
const Duration defaultBootTimeout = Duration(seconds: 10);

sealed class BootEvent {
  const BootEvent();
}

/// Starts the first attempt. Ignored once an attempt has started.
final class BootStarted extends BootEvent {
  const BootStarted();
}

/// Starts the next attempt from [BootFailed] or [BootTimedOut].
final class BootRetried extends BootEvent {
  const BootRetried();
}

final class _BootSucceeded extends BootEvent {
  const _BootSucceeded(this.attempt);

  final int attempt;
}

final class _BootThrew extends BootEvent {
  const _BootThrew(this.attempt, this.error, this.stackTrace);

  final int attempt;
  final Object error;
  final StackTrace stackTrace;
}

final class _BootTimeoutElapsed extends BootEvent {
  const _BootTimeoutElapsed(this.attempt);

  final int attempt;
}

/// Boot with an error state, a timeout and Retry (D-21, fixes P-028).
///
/// - [BootStarted] runs the task and moves to [BootReady] or [BootFailed]
///   (which [McBloc] records to monitoring). If the task has not finished
///   after [timeout], the state becomes [BootTimedOut].
/// - [BootRetried] after a failure runs the task again. After a timeout it
///   waits for the same, still-running task with a fresh timeout, because the
///   root container accepts one initialisation at a time; a task that
///   finished while the timeout screen showed is picked up at once.
/// - A result for an attempt that is no longer current (it timed out) does
///   not change the state by itself (attempt counter).
final class BootBloc extends McBloc<BootEvent, BootState> {
  BootBloc({
    required BootTask task,
    required super.monitoring,
    this.timeout = defaultBootTimeout,
  }) : _task = task,
       super(const BootBooting(0)) {
    on<BootStarted>((event, emit) {
      if (_attempt == 0) {
        _begin(emit);
      }
    });
    on<BootRetried>((event, emit) {
      if (state is BootFailed || state is BootTimedOut) {
        _begin(emit);
      }
    });
    on<_BootSucceeded>((event, emit) {
      if (_isCurrent(event.attempt)) {
        _timer?.cancel();
        emit(const BootReady());
      }
    });
    on<_BootThrew>((event, emit) {
      if (_isCurrent(event.attempt)) {
        _timer?.cancel();
        emit(BootFailed(event.attempt, event.error, event.stackTrace));
      }
    });
    on<_BootTimeoutElapsed>((event, emit) {
      if (_isCurrent(event.attempt)) {
        emit(BootTimedOut(event.attempt, timeout));
      }
    });
  }

  final BootTask _task;
  final Duration timeout;

  int _attempt = 0;
  Future<void>? _run;
  Timer? _timer;

  /// How many times the task was started (a retry after a timeout reuses the
  /// running task, so it does not count).
  int get taskRuns => _taskRuns;
  int _taskRuns = 0;

  void _begin(Emitter<BootState> emit) {
    final attempt = ++_attempt;
    emit(BootBooting(attempt));
    final run = _run ??= _startRun();
    _timer?.cancel();
    _timer = Timer(timeout, () => _send(_BootTimeoutElapsed(attempt)));
    run.then(
      (_) => _send(_BootSucceeded(attempt)),
      onError: (Object error, StackTrace stackTrace) =>
          _send(_BootThrew(attempt, error, stackTrace)),
    );
  }

  Future<void> _startRun() {
    _taskRuns++;
    final run = Future<void>.sync(_task);
    // A failed run is discarded, so the next attempt starts a fresh one.
    run.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_run, run)) {
          _run = null;
        }
      },
    );
    return run;
  }

  bool _isCurrent(int attempt) => attempt == _attempt && state is BootBooting;

  void _send(BootEvent event) {
    if (!isClosed) {
      add(event);
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
