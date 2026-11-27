// The public surface (R4, checked by mc_arch_check and the architecture
// test): the flow, its navigator and the navigator's argument type. No
// `library;` directive (Tide's `unnecessary_library_directive`).
export 'package:trivia_quiz/src/domain/model/comic_id.dart' show ComicId;
export 'package:trivia_quiz/src/flow/trivia_quiz_flow.dart' show TriviaQuizFlow;
export 'package:trivia_quiz/src/navigator/trivia_quiz_navigator.dart'
    show TriviaQuizNavigator;
