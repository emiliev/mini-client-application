import 'package:mc_bloc_kit/mc_bloc_kit.dart';

/// Where boot is (plan 01 §3.4, R29). Until [BootReady] no `GoRouter`
/// exists, so no route builder or `redirect` can run.
sealed class BootState {
  const BootState();
}

/// Root DI initialisation is running. [attempt] starts at 1.
final class BootBooting extends BootState {
  const BootBooting(this.attempt);

  final int attempt;
}

/// An initializer threw. Retry starts a fresh attempt. `McBloc` records the
/// error to monitoring.
final class BootFailed extends BootState implements McFailureState {
  const BootFailed(this.attempt, this.error, this.stackTrace);

  final int attempt;
  @override
  final Object error;
  @override
  final StackTrace stackTrace;
}

/// The attempt took longer than the boot timeout. A late result still
/// counts (ready or failed). Retry abandons the attempt and starts a fresh
/// one (`abandonDIContainerInitialization`), so no type is registered twice.
final class BootTimedOut extends BootState {
  const BootTimedOut(this.attempt, this.timeout);

  final int attempt;
  final Duration timeout;
}

/// The root container is published. Terminal.
final class BootReady extends BootState {
  const BootReady();
}
