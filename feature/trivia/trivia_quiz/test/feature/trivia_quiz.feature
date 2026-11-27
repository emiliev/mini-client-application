Feature: Playing a trivia round
  The setup lists the categories (and, signed in, the best score of each).
  A round is ten questions of four choices, each with a countdown; an answer
  is judged at once, with the points and the streak. The results show the
  score, the correct count and the best score once the server has saved it.

  Background:
    Given the backend serves {'trivia.default'}
    And the backend serves {'identity.default'}

  @T-0064-AC1 @smoke
  Scenario: Characters / Easy: ten questions in turn, then the results with the score, the correct count and the best
    Given I am signed in as {'reader@mini-client.test'}
    When I open the trivia
    Then the setup shows the categories {'All categories, Characters, Comics, Creators'}
    And the category {'characters'} shows the best {1340}
    When I pick the category {'characters'} and the difficulty {'easy'}
    And I start the round
    And I play the answers {'C1000 C1000 W0 C0 C0 C0 C2000 C0 C0 C0'}
    Then the questions shown were those of the {'characters'} {'easy'} round of seed {42} in order
    And every question showed four choices and a countdown of {20} seconds
    And the results show {9} correct and the score the server saved
    And the results show the score as the new best of {'characters'} for {'reader@mini-client.test'}
    And the backend received {1} requests for {'POST /v1/me/trivia/results'}
    And the backend received {'POST /v1/me/trivia/results'} with the bearer of {'reader@mini-client.test'}
    And no error was reported

  @T-0064-AC1
  Scenario: Signed out, the setup shows no best and asks the server for none
    When I open the trivia
    Then the setup shows the categories {'All categories, Characters, Comics, Creators'}
    And no category shows a best score
    And the backend received {0} requests for {'GET /v1/me/trivia/best'}

  @T-0064-AC1
  Scenario: Back from the results, the setup shows the new best
    Given I am signed in as {'reader@mini-client.test'}
    When I open the trivia
    And I pick the category {'all'} and the difficulty {'easy'}
    And I start the round
    And I play the answers {'C1000 C0x9'}
    Then the results show the score {2622} and {10} correct
    And I see {'New best!'}
    When I go back
    Then the category {'all'} shows the best {2622}

  @T-0064-AC1
  Scenario: Play again starts a new round of the same category and difficulty
    Given the next round seeds are {'42, 7'}
    And I am signed in as {'reader@mini-client.test'}
    When I open the trivia
    And I pick the category {'comics'} and the difficulty {'hard'}
    And I start the round
    And I play the answers {'W1000 W0x9'}
    And I play again
    Then the round shows the first question of the {'comics'} {'hard'} round of seed {7}

  @T-0064-AC1
  Scenario: The best scores follow the session
    Given I am signed in as {'reader@mini-client.test'}
    When I open the trivia
    Then the category {'all'} shows the best {870}
    When {'collector@mini-client.test'} signs in elsewhere
    Then no category shows a best score
    And the backend received {2} requests for {'GET /v1/me/trivia/best'}

  @T-0064-AC1
  Scenario: A failed read of the best scores keeps the categories usable
    Given I am signed in as {'reader@mini-client.test'}
    And the backend fails {'GET /v1/me/trivia/best'} with {'server_error'}
    When I open the trivia
    Then the setup shows the categories {'All categories, Characters, Comics, Creators'}
    And no category shows a best score

  @T-0064-AC2
  Scenario: The categories fail, and Retry recovers
    Given the backend runs the scenario {'trivia.server_error'}
    When I open the trivia
    Then I see {'The categories could not be loaded.'}
    And I see {'The server had a problem. Please try again later.'}
    When the backend recovers
    And I tap {'Retry'}
    Then the setup shows the categories {'All categories, Characters, Comics, Creators'}

  @T-0064-AC2
  Scenario: With no categories, the setup shows the empty state
    Given the backend runs the scenario {'trivia.empty'}
    When I open the trivia
    Then I see {'No trivia yet'}
    And I see {'There are no trivia categories yet.'}

  @T-0064-AC2
  Scenario: The round fails to load, and Retry plays it
    Given the backend fails {'GET /v1/trivia/rounds'} with {'server_error'}
    When I open the round {'all'} {'easy'} of seed {42}
    Then I see {'This round could not be loaded.'}
    When the backend recovers
    And I tap {'Retry'}
    Then the round shows the first question of the {'all'} {'easy'} round of seed {42}

  @T-0064-AC2
  Scenario: A failed save shows the local score, not saved, and Retry saves exactly once
    Given I am signed in as {'reader@mini-client.test'}
    And the backend fails {'POST /v1/me/trivia/results'} with {'server_error'}
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0 C0 W0x8'}
    Then the results show the score {325} and {2} correct
    And I see {'Your score was not saved. The server had a problem. Please try again later.'}
    When the backend recovers
    And I tap {'Retry'} twice in quick succession
    Then the results show the score {325} and {2} correct
    And I see {'Best: 870'}
    And the backend received {2} requests for {'POST /v1/me/trivia/results'}
    And the best of {'reader@mini-client.test'} for {'all'} is {870}

  @T-0064-AC3
  Scenario: Quitting asks first, and Confirm goes back to the setup
    When I open the trivia
    And I start the round
    And {1000} milliseconds pass
    And I ask to quit the round
    Then I see {'Quit this round?'}
    When I confirm the dialog
    Then the setup shows the categories {'All categories, Characters, Comics, Creators'}

  @T-0064-AC3
  Scenario: Opened at a round, confirming quit leaves the quiz
    When I open the round {'all'} {'easy'} of seed {42} over another screen
    And {3000} milliseconds pass
    And I ask to quit the round
    And I confirm the dialog
    Then the screen under the quiz is shown

  @T-0064-AC3
  Scenario: Quitting while the round loads leaves at once, with no dialog
    Given the backend holds {'GET /v1/trivia/rounds'}
    When I open the round {'all'} {'easy'} of seed {42} over another screen
    And I ask to quit the round
    Then I don't see {'Quit this round?'}
    And the screen under the quiz is shown
    When the backend releases {'GET /v1/trivia/rounds'}
    Then the screen under the quiz is shown

  @T-0064-AC3
  Scenario: Signed out, Save your score asks to sign in and saves for that user
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0 W0x9'}
    Then I see {'Sign in to save your score and see your best.'}
    And the backend received {0} requests for {'POST /v1/me/trivia/results'}
    When I tap {'Save your score'}
    Then the app was asked to sign in {1} times
    And I see {'Waiting for you to sign in.'}
    When signing in succeeds as {'collector@mini-client.test'}
    Then I see {'Best: 150'}
    And I see {'New best!'}
    And the backend received {1} requests for {'POST /v1/me/trivia/results'}
    And the backend received {'POST /v1/me/trivia/results'} with the bearer of {'collector@mini-client.test'}

  @T-0064-AC3
  Scenario: Signed out, backing out of signing in saves nothing
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0 W0x9'}
    And I tap {'Save your score'} twice in quick succession
    Then the app was asked to sign in {1} times
    When signing in is cancelled
    Then I see {'Sign in to save your score and see your best.'}
    And the backend received {0} requests for {'POST /v1/me/trivia/results'}

  @T-0064-AC3
  Scenario: Signed out, a sign-in answer of yes with nobody signed in saves nothing
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0 W0x9'}
    And I tap {'Save your score'}
    And the sign in sheet answers yes but nobody is signed in
    Then I see {'Sign in to save your score and see your best.'}
    And the backend received {0} requests for {'POST /v1/me/trivia/results'}

  @T-0064-AC3
  Scenario: A user switch while the result is on its way drops the answer, and Retry saves for the new user
    Given I am signed in as {'reader@mini-client.test'}
    And the backend holds the next {'POST /v1/me/trivia/results'}
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0x10'}
    And the app sends {'POST /v1/me/trivia/results'}
    And {'collector@mini-client.test'} signs in elsewhere
    And the backend releases {'POST /v1/me/trivia/results'}
    Then I see {'Your score was not saved. Something went wrong.'}
    And I don't see {'Best: 2625'}
    And the backend received {'POST /v1/me/trivia/results'} with a token of {'reader@mini-client.test'}
    When I tap {'Retry'}
    Then I see {'Best: 2625'}
    And the backend received {2} requests for {'POST /v1/me/trivia/results'}
    And the best of {'collector@mini-client.test'} for {'all'} is {2625}

  @T-0064-AC3
  Scenario: A user switch right before the result is sent sends nothing under the old user, and Retry saves for the new one
    Given I am signed in as {'reader@mini-client.test'}
    And {'collector@mini-client.test'} signs in just before the app sends {'POST /v1/me/trivia/results'}
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0x10'}
    And the app finishes writing to storage
    Then I see {'Your score was not saved. Something went wrong.'}
    And the backend received {0} requests for {'POST /v1/me/trivia/results'}
    When I tap {'Retry'}
    Then I see {'Best: 2625'}
    And the backend received {1} requests for {'POST /v1/me/trivia/results'}
    And the backend received {'POST /v1/me/trivia/results'} with the bearer of {'collector@mini-client.test'}
    And the best of {'reader@mini-client.test'} for {'all'} is {870}

  @T-0064-AC3
  Scenario: A question about a comic opens it once, even on a double tap
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'W0x10'}
    And I tap the comic of the first question about a comic twice in quick succession
    Then the app was asked to open the comic of the first question about a comic once

  @T-0064-AC1 @T-0064-AC7
  Scenario: The round is tracked: started, each answer, finished, and the three screens
    When I open the trivia
    And I pick the category {'creators'} and the difficulty {'hard'}
    And I start the round
    And I play the answers {'C1000 C9000 W0 N0 C2600 C5000 C7500 C0 W0 C0'}
    Then the analytics event {'trivia_round_started'} was tracked with
      | 'key'        | 'json'       |
      | 'category'   | '"creators"' |
      | 'difficulty' | '"hard"'     |
    And the answers were tracked with the buckets {'q1 q4 q1 timeout q2 q3 q4 q1 q1 q1'}
    And the analytics event {'trivia_round_finished'} was tracked with
      | 'key'   | 'json'   |
      | 'score' | '1099'   |
    And the screens tracked are {'trivia_setup, trivia_play, trivia_results'}

  @T-0064-AC6
  Scenario: With the hint experiment on, the 50/50 hint hides two wrong choices once per round
    Given the experiment {'trivia_hint'} is in variant {'hint'}
    When I open the round {'all'} {'easy'} of seed {42}
    And I use the hint
    Then the question shows only the correct choice and one wrong choice
    And the hint is not offered
    When I answer {'C'} after {0} milliseconds
    Then the question shows {'Correct! +100'}
    And the question shows {'Hint used'}
    When I go to the next question
    Then the hint is not offered
    And the question shows four choices

  @T-0064-AC6
  Scenario: Without the hint experiment there is no hint
    When I open the round {'all'} {'easy'} of seed {42}
    Then the hint is not offered
