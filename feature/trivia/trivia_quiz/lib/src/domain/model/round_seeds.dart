/// Where a new round's seed comes from when none is asked for: the app
/// passes a random source, tests a fixed one.
final class RoundSeeds {
  const RoundSeeds(this.next);

  /// A round seed from 0 to 2^31 - 1 (the contract's range).
  final int Function() next;
}
