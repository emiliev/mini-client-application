/// A comic's id in this feature's own vocabulary (features never share types,
/// plan 01 §4.3): a product, a deal and a comic banner open the comic by it,
/// so the barrel exports it with the navigator.
///
/// An extension type: an `int` at run time, but not interchangeable with
/// other ids at compile time.
extension type const ComicId(int value) {}
