/// Typed locations for navigation across wiring groups (plan 01 §4.2). A
/// wiring never imports another wiring, so it reaches another group's routes
/// through these. Each app tests `AppLocations.x(...) == XRoute(...).location`.
abstract final class AppLocations {
  /// The home placeholder (T-0021).
  static const String home = '/';

  /// The placeholder detail route (T-0021), the deep-link probe until real
  /// features exist.
  static String placeholder(int id) => '/placeholder/$id';

  /// The characters list (T-0033). Equals `CharactersRoute().location` in
  /// universe_wiring.
  static const String characters = '/characters';

  /// One character's details (T-0033), by the `CharacterId` value. Equals
  /// `CharacterDetailsRoute(id: id).location` in universe_wiring.
  static String character(int id) => '/characters/$id';
}
