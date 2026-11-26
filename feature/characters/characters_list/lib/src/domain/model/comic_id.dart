/// A comic's id in this feature's own vocabulary: one of the character's
/// related comics on the preview. The navigator takes it (`openComic`), so
/// the barrel exports it. It is not the type `comics_details` declares
/// (features never share types, plan 01 §4.3); the wiring maps between them.
extension type const ComicId(int value) {}
