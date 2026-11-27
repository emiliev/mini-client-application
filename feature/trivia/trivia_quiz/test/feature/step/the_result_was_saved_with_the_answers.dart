import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the result was saved with the answers {'C0 W0x9'}
///
/// The last `POST /v1/me/trivia/results` carried one answer per question in
/// round order, as the tokens say: the correct or a wrong choice with
/// exactly the token's elapsed time; no choice and the limit for a token at
/// or past the limit, or a no-answer (the app timed it out); `hint: true`
/// only on the hinted one.
Future<void> theResultWasSavedWithTheAnswers(
  WidgetTester tester,
  String answers,
) async {
  final round = await currentRound(tester);
  final post = McTestSession.current.backend.requests.lastWhere(
    (r) => r.routeKey == 'POST /v1/me/trivia/results',
  );
  final body = post.body! as Map<Object?, Object?>;
  expect(body['roundId'], round['roundId']);
  final sent = (body['answers']! as List).cast<Map<Object?, Object?>>();
  final tokens = parseAnswerTokens(answers);
  final questions = questionsOf(round);
  expect(sent, hasLength(questions.length));
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    final t = tokens[i];
    final limit = (q['timeLimitSeconds']! as int) * 1000;
    final a = sent[i];
    expect(a['questionId'], q['id'], reason: 'answer $i in round order');
    if (t.kind == 'N' || t.elapsedMs >= limit) {
      expect(a['choiceId'], isNull, reason: 'answer $i timed out');
      expect(a['elapsedMs'], limit, reason: 'answer $i at the limit');
    } else {
      expect(a['elapsedMs'], t.elapsedMs, reason: 'answer $i elapsed');
      if (t.kind == 'C') {
        expect(a['choiceId'], q['correctChoiceId'], reason: 'answer $i');
      } else {
        expect(a['choiceId'], isNot(q['correctChoiceId']), reason: '$i');
        expect(a['choiceId'], isNotNull, reason: 'answer $i');
      }
    }
    expect(a['hint'], t.hint ? isTrue : isNull, reason: 'answer $i hint');
  }
}
