/// The time the deals count down against ("ends in 3 days"). Injected: the
/// app passes the backend's clock (the mocked backend's is fixed at
/// `2026-01-01T00:00Z`, so its deals always end 1 to 8 days later), and tests
/// pass the fixtures' fixed clock. Provided by the flow (`provide:`), so it is
/// not a root import.
final class StoreClock {
  const StoreClock(this.now);

  final DateTime Function() now;
}
