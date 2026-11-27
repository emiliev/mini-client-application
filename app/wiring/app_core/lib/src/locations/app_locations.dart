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

  /// One comic (T-0041), by the `ComicId` value. Equals
  /// `ComicDetailsRoute(id: id).location` in publishing_wiring.
  static String comic(int id) => '/comics/$id';

  /// The search (T-0046), starting with [query] when given (encoded as a
  /// query parameter). Equals `SearchRoute(q: query).location` in
  /// discovery_wiring.
  static String search([String? query]) => Uri(
    path: '/search',
    queryParameters: query == null ? null : {'q': query},
  ).toString();

  /// The reading-list editor on a new list (T-0048). Equals
  /// `NewReadingListRoute().location` in library_wiring. It ends with a
  /// result: push it through `AppFlows.createReadingList`.
  static const String newReadingList = '/me/lists/new';

  /// The reading-list editor on list [id] (T-0048). Equals
  /// `EditReadingListRoute(id: id).location` in library_wiring. It ends with
  /// a result: push it through `AppFlows.editReadingList`.
  static String editReadingList(String id) =>
      '/me/lists/${Uri.encodeComponent(id)}/edit';
}
