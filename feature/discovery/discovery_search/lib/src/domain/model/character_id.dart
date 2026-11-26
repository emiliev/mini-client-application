/// A character's id as this feature names it: a character among the results.
/// The navigator takes it (`openCharacter`), so the barrel exports it. The
/// wiring maps it to the app's character location; it is not the type
/// `characters_list` or `comics_details` declares (features never share
/// types, plan 01 §4.3).
///
/// An extension type: an `int` at run time, but not interchangeable with
/// other ids at compile time.
extension type const CharacterId(int value) {}
