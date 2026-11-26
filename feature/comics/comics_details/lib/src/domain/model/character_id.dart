/// A character's id as this feature names it: a member of the comic's cast.
/// The navigator takes it (`openCharacter`), so the barrel exports it. The
/// wiring maps it to the app's character location; it is not the type
/// `characters_list` declares (features never share types, plan 01 §4.3).
extension type const CharacterId(int value) {}
