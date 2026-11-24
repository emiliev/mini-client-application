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
/// Each attempt runs the task once:
/// - success → [BootReady], also when it arrives after the timeout screen
///   showed;
/// - failure → [BootFailed] (recorded to monitoring by [McBloc]), also after
///   the timeout screen;
/// - no result within [timeout] → [BootTimedOut]; the attempt stays live.
///
/// [BootRetried] from [BootFailed] starts a fresh attempt. From
/// [BootTimedOut] it first calls [abandon] (for the real app,
/// `abandonDIContainerInitialization`, which releases `mc_di`'s in-flight
/// guard and makes the stuck run discard its staged container), then starts
/// a fresh attempt. Results of an abandoned attempt are ignored.
final class BootBloc extends McBloc<BootEvent, BootState> {
  BootBloc({
    required BootTask task,
    required super.monitoring,
    void Function()? abandon,
    this.timeout = defaultBootTimeout,
  }) : _task = task,
       _abandon = abandon ?? _noop,
       super(const BootBooting(0)) {
    on<BootStarted>((event, emit) {
      if (_attempt == 0) {
        _begin(emit);
      }
    });
    on<BootRetried>((event, emit) {
      switch (state) {
        case BootFailed():
          _begin(emit);
        case BootTimedOut():
          _abandon();
          _begin(emit);
        case BootBooting() || BootReady():
          break;
      }
    });
    on<_BootSucceeded>((event, emit) {
      if (_isLive(event.attempt)) {
        _timer?.cancel();
        emit(const BootReady());
      }
    });
    on<_BootThrew>((event, emit) {
      if (_isLive(event.attempt)) {
        _timer?.cancel();
        emit(BootFailed(event.attempt, event.error, event.stackTrace));
      }
    });
    on<_BootTimeoutElapsed>((event, emit) {
      if (event.attempt == _attempt && state is BootBooting) {
        emit(BootTimedOut(event.attempt, timeout));
      }
    });
  }

  static void _noop() {}

  final BootTask _task;
  final void Function() _abandon;
  final Duration timeout;

  int _attempt = 0;
  Timer? _timer;

  /// How many times the task was started (once per attempt).
  int get taskRuns => _taskRuns;
  int _taskRuns = 0;

  void _begin(Emitter<BootState> emit) {
    final attempt = ++_attempt;
    emit(BootBooting(attempt));
    _timer?.cancel();
    _timer = Timer(timeout, () => _send(_BootTimeoutElapsed(attempt)));
    _taskRuns++;
    Future<void>.sync(_task).then(
      (_) => _send(_BootSucceeded(attempt)),
      onError: (Object error, StackTrace stackTrace) =>
          _send(_BootThrew(attempt, error, stackTrace)),
    );
  }

  /// The attempt is the current one and still waiting for its result.
  bool _isLive(int attempt) =>
      attempt == _attempt && (state is BootBooting || state is BootTimedOut);

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
