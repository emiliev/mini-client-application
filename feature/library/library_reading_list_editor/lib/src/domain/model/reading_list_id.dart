/// A reading list's id in this feature's own vocabulary (`l-5`): the flow's
/// argument in edit mode and the flow's result once a list is saved, so the
/// barrel exports it. Features never share types (plan 01 §4.3): the wiring
/// maps it to the app's `String` at the route.
///
/// An extension type: a `String` at run time, but not interchangeable with
/// other ids at compile time.
extension type const ReadingListId(String value) {}
