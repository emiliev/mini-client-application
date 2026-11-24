// The annotation scan matches "@injectable" in this comment, so the file gets
// a shard, but the generator finds no injectable class: its shard is `[]`
// (T-0028-AC4).

/// Not registered in DI.
class PlainHelper {
  const PlainHelper();

  String shout(String s) => s.toUpperCase();
}
