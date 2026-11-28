import 'package:app_core/src/sign_in/sign_in_request.dart';

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

  /// The character search (T-0071), starting with [query] when given
  /// (encoded as a query parameter). Equals
  /// `CharactersSearchRoute(q: query).location` in universe_wiring.
  static String charactersSearch([String? query]) => Uri(
    path: '/characters/search',
    queryParameters: query == null ? null : {'q': query},
  ).toString();

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

  /// The store home (T-0056). Equals `StoreRoute().location` in
  /// commerce_wiring.
  static const String store = '/store';

  /// The store opened at category [id] (T-0056), encoded as go_router_builder
  /// encodes a path parameter. Equals `StoreCategoryRoute(id: id).location`
  /// in commerce_wiring.
  static String storeCategory(String id) =>
      '/store/categories/${Uri.encodeComponent(id)}';

  /// The trivia quiz's setup (T-0064). Equals `TriviaRoute().location` in
  /// chronicle_wiring.
  static const String trivia = '/trivia';

  /// The trivia quiz opened at a round (T-0064): each given value is a query
  /// parameter. Equals `TriviaPlayRoute(...).location` in chronicle_wiring.
  static String triviaPlay({String? category, String? difficulty, int? seed}) {
    final query = {
      if (category != null) 'category': category,
      if (difficulty != null) 'difficulty': difficulty,
      if (seed != null) 'seed': '$seed',
    };
    return Uri(
      path: '/trivia/play',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  /// The settings index (T-0070). Equals `SettingsHomeRoute().location` in
  /// account_wiring. The appearance settings are nested under it.
  static const String settings = '/settings';

  /// The appearance settings (T-0063), under the settings index: a link
  /// opens `[home, settings, appearance]`. Equals
  /// `SettingsAppearanceRoute().location` in account_wiring.
  static const String settingsAppearance = '/settings/appearance';

  /// The catalogue (T-0074, P2-08): every generated flow, one tap away. A
  /// debug screen: home has no link to it, and release builds no route.
  static const String catalogue = '/catalogue';

  /// The sign-in screen (T-0066), which ends with a result (push it through
  /// `AppFlows.signIn`). Equals `SignInRoute(...).location` in
  /// account_wiring.
  ///
  /// [from] is where the guard was sending the user: after signing in, the
  /// screen goes there, if it is a location of this app (`safeSignInTarget`).
  /// [reason] says what signing in is for. Both are query parameters.
  static String signIn({String? from, SignInPurpose? reason}) {
    final query = {
      if (from != null) 'from': from,
      if (reason != null) 'reason': reason.name,
    };
    return Uri(
      path: '/auth/sign-in',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}
