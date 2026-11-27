/// A comic's id as this feature names it: an appearance of the character.
/// The navigator takes it (`openComic`), so the barrel exports it. The wiring
/// maps it to the app's comic location; it is not the type `comics_details`
/// declares (features never share types, plan 01 §4.3).
extension type const ComicId(int value) {}
