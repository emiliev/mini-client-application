/// A store category's id (`heroes`, `cosmic`, ...). The flow can open at a
/// category (`/store/categories/:id`), so the barrel exports it.
///
/// An extension type: a `String` at run time, but not interchangeable with
/// other text at compile time.
extension type const CategoryId(String value) {}
