/// A character's id in this feature's own vocabulary (features never share
/// types, plan 01 §4.3). The navigator takes it, so the barrel exports it.
///
/// An extension type: an `int` at run time, but not interchangeable with
/// other ids at compile time.
extension type const CharacterId(int value) {}
