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

/// An initializer threw. Retry starts a fresh attempt.
final class BootFailed extends BootState {
  const BootFailed(this.attempt, this.error, this.stackTrace);

  final int attempt;
  final Object error;
  final StackTrace stackTrace;
}

/// The attempt took longer than the boot timeout. Retry waits for the
/// still-running initialisation again (it never starts a second one, so no
/// type is registered twice).
final class BootTimedOut extends BootState {
  const BootTimedOut(this.attempt, this.timeout);

  final int attempt;
  final Duration timeout;
}

/// The root container is published. Terminal.
final class BootReady extends BootState {
  const BootReady();
}
