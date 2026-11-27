Feature: The countdown, under fake time
  Each question has its own limit (20, 15 and 10 seconds by difficulty). The
  countdown ends the question exactly at the limit: one millisecond before,
  the question is still open. It runs only while someone can play: in the
  background, under the quit dialog or covered by another screen it stops,
  and it goes on from where it stopped. With reduce motion the ring is not
  drawn: the number only. The app draws no frame while it is hidden or
  paused, so those checks come once it is back in the foreground.

  Background:
    Given the backend serves {'trivia.default'}

  @T-0064-AC6
  Scenario Outline: On <difficulty> the question times out at <limit> ms, not one millisecond before
    When I open the round {'all'} {<difficulty>} of seed {42}
    Then the question is open with {<seconds>} seconds left
    When {<before>} milliseconds pass
    Then the question is open with {1} seconds left
    When {1} milliseconds pass
    Then the question timed out
    And the analytics event {'trivia_answer'} was tracked with
      | 'key'            | 'json'      |
      | 'correct'        | 'false'     |
      | 'elapsed_bucket' | '"timeout"' |

    Examples:
      | difficulty | seconds | limit | before |
      | 'easy'     | 20      | 20000 | 19999  |
      | 'medium'   | 15      | 15000 | 14999  |
      | 'hard'     | 10      | 10000 | 9999   |

  @T-0064-AC6
  Scenario Outline: On <difficulty> a millisecond past the limit the question has timed out
    When I open the round {'all'} {<difficulty>} of seed {42}
    And {<after>} milliseconds pass
    Then the question timed out

    Examples:
      | difficulty | after |
      | 'easy'     | 20001 |
      | 'medium'   | 15001 |
      | 'hard'     | 10001 |

  @T-0064-AC6
  Scenario Outline: In the background (<state>) the countdown stops, and it resumes where it stopped
    When I open the round {'all'} {'easy'} of seed {42}
    And {5000} milliseconds pass
    And the app lifecycle becomes {<state>}
    And {60000} milliseconds pass
    And the app lifecycle becomes {'resumed'}
    Then the question is open with {15} seconds left
    When {14999} milliseconds pass
    Then the question is open with {1} seconds left
    When {1} milliseconds pass
    Then the question timed out

    Examples:
      | state      |
      | 'inactive' |
      | 'hidden'   |
      | 'paused'   |

  @T-0064-AC6
  Scenario: A tap on the correct choice at the limit is a timeout, and no choice is marked as the player's
    When I open the round {'all'} {'easy'} of seed {42}
    And I answer {'C'} after {20000} milliseconds
    Then the question timed out
    And the choices carry the marks {''}

  @T-0064-AC6
  Scenario: A judged answer marks the player's choice
    When I open the round {'all'} {'easy'} of seed {42}
    And I answer {'W'} after {1000} milliseconds
    Then the choices carry the marks {'cross'}
    When I go to the next question
    And I answer {'C'} after {1000} milliseconds
    Then the choices carry the marks {'check'}

  @T-0064-AC6
  Scenario: Time in the background does not count towards an answer
    When I open the round {'all'} {'easy'} of seed {42}
    And {4000} milliseconds pass
    And the app lifecycle becomes {'paused'}
    And {90000} milliseconds pass
    And the app lifecycle becomes {'resumed'}
    And I answer {'C'} after {1000} milliseconds
    Then the question shows {'Correct! +137'}

  @T-0064-AC3 @T-0064-AC6
  Scenario: The countdown stops while the quit dialog is open, and Cancel resumes the round
    When I open the round {'all'} {'easy'} of seed {42}
    And {5000} milliseconds pass
    And I ask to quit the round
    Then I see {'Quit this round?'}
    And the countdown shows it is paused
    When {60000} milliseconds pass
    And I keep playing
    Then the question is open with {15} seconds left
    When I answer {'C'} after {5000} milliseconds
    Then the question shows {'Correct! +125'}

  @T-0064-AC4
  Scenario: With reduce motion the countdown is the number only
    Given reduce motion is on
    When I open the round {'all'} {'easy'} of seed {42}
    Then the countdown is the number only
    When {3000} milliseconds pass
    Then the question is open with {17} seconds left
    And the countdown is the number only

  @T-0064-AC4
  Scenario: Without reduce motion the countdown is a ring around the number
    When I open the round {'all'} {'easy'} of seed {42}
    Then the countdown is a ring around the number
