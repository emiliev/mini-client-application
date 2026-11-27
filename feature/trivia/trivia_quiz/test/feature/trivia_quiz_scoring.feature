Feature: Scoring a round, exactly as the server does
  The quiz's engine scores every answer at once, for instant feedback, with
  the rules of mc_fixtures_editorial's CONTRACT.md; the server scores the
  submitted round again and its score is the one kept. The worked examples of
  the contract are the Examples below, row for row (a test checks the two
  tables are the same). Each row is played through the flow on the seed-42
  round of every category, with fake time setting how long each answer took:
  the score shown while the result is saved is the engine's, and once saved
  it is the server's, and both are the row's. A no-answer (`N<ms>`) can only
  happen in the app by letting the time run out, which scores the same (0,
  and the streak resets).

  Background:
    Given the backend serves {'trivia.default'}
    And the backend serves {'identity.default'}
    And I am signed in as {'reader@mini-client.test'}

  @T-0064-AC6
  Scenario Outline: <id>: the answers <answers> on <difficulty> score <score> with <correct> correct, locally and on the server
    Given the backend holds the next {'POST /v1/me/trivia/results'}
    When I open the round {'all'} {<difficulty>} of seed {42}
    And I play the answers {<answers>}
    Then the results show the score {<score>} and {<correct>} correct
    And I see {'Saving your score…'}
    When the backend releases {'POST /v1/me/trivia/results'}
    Then the results show the score {<score>} and {<correct>} correct
    And the result was saved with the answers {<answers>}
    And no error was reported

    Examples:
      | id | difficulty | answers | score | correct |
      | 'E1' | 'easy' | 'C0 W0x9' | 150 | 1 |
      | 'E2' | 'easy' | 'C5000 W0x9' | 137 | 1 |
      | 'E3' | 'easy' | 'C10000 W0x9' | 125 | 1 |
      | 'E4' | 'easy' | 'C19999 W0x9' | 100 | 1 |
      | 'E5' | 'easy' | 'C20000 W0x9' | 0 | 0 |
      | 'E6' | 'easy' | 'C20001 W0x9' | 0 | 0 |
      | 'E7' | 'medium' | 'C7000 W0x9' | 126 | 1 |
      | 'E8' | 'hard' | 'C3333 W0x9' | 133 | 1 |
      | 'E9' | 'easy' | 'W0x10' | 0 | 0 |
      | 'E10' | 'easy' | 'N0x10' | 0 | 0 |
      | 'E11' | 'easy' | 'C0 C0 W0x8' | 325 | 2 |
      | 'E12' | 'easy' | 'C0 C0 C0 W0 C0 C0 N0 C0 C0 C0' | 1375 | 8 |
      | 'E13' | 'easy' | 'C0x10' | 2625 | 10 |
      | 'E14' | 'hard' | 'C1000 C2000 C3000 W0x7' | 495 | 3 |
      | 'E15' | 'medium' | 'C14999x10' | 2125 | 10 |
      | 'E16' | 'easy' | 'C0 C20000 C0 C0 W0x6' | 475 | 3 |
      | 'E17' | 'easy' | 'C0 C0 W19999 C0 W0x6' | 475 | 3 |

  @T-0064-AC6
  Scenario Outline: <id>: with the 50/50 hint, the answers <answers> on <difficulty> score <score>, locally and on the server
    Given the experiment {'trivia_hint'} is in variant {'hint'}
    And the backend holds the next {'POST /v1/me/trivia/results'}
    When I open the round {'all'} {<difficulty>} of seed {42}
    And I play the answers {<answers>}
    Then the results show the score {<score>} and {<correct>} correct
    When the backend releases {'POST /v1/me/trivia/results'}
    Then the results show the score {<score>} and {<correct>} correct
    And the result was saved with the answers {<answers>}
    And no error was reported

    Examples:
      | id | difficulty | answers | score | correct |
      | 'H1' | 'easy' | 'C0h W0x9' | 100 | 1 |
      | 'H2' | 'easy' | 'C0 C0h C0 W0x7' | 475 | 3 |
      | 'H3' | 'easy' | 'W0h C0 W0x8' | 150 | 1 |
      | 'H4' | 'hard' | 'C9999h W0x9' | 50 | 1 |
      | 'H5' | 'easy' | 'N0h C0x9' | 2250 | 9 |

  @T-0064-AC6
  Scenario: Seed 42 gives the same round every time, and the engine's score is the server's
    When I open the round {'characters'} {'medium'} of seed {42}
    And I play the answers {'C0 W0 C1500 N0 C0 C0 W0 C0 C7000 C0'}
    Then the questions shown were those of the {'characters'} {'medium'} round of seed {42} in order
    And the results show the score {1121} and {7} correct
    And the result was saved with the answers {'C0 W0 C1500 N0 C0 C0 W0 C0 C7000 C0'}
    And no error was reported

  @T-0064-AC6
  Scenario: When the server's score differs from the engine's, the server's is shown and the mismatch is reported once
    Given the server scores every round {999}
    When I open the round {'all'} {'easy'} of seed {42}
    And I play the answers {'C0x10'}
    Then the results show the score {999} and {10} correct
    And the points per question are {'999 0 0 0 0 0 0 0 0 0'}
    And {1} errors were reported
