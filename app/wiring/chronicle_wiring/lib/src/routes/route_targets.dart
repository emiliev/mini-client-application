import 'package:trivia_quiz/trivia_quiz.dart';

/// What the chronicle group's typed routes build (R15): each member returns
/// a feature's `*Flow`. The route files import only this interface;
/// `ChronicleRouteTargetsImpl` (unannotated) supplies the flows' navigators
/// and is registered by `ChronicleWiringDIInitializer`.
///
/// Prefixed with the group because the app imports every wiring's barrel
/// side by side (F-0040 fact 11).
abstract interface class ChronicleRouteTargets {
  /// The quiz's setup: `/trivia`.
  TriviaQuizFlow trivia();

  /// The quiz opened at a round: `/trivia/play?category=&difficulty=&seed=`.
  /// A missing category or difficulty plays `all` or `easy`; a missing seed
  /// draws a new one. The server checks the values (an unknown one shows the
  /// round's error).
  TriviaQuizFlow triviaRound({
    String? category,
    String? difficulty,
    int? seed,
  });
}
