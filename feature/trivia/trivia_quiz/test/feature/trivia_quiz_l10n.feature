Feature: The quiz in German and in the pseudo-locale
  Every page reads in the device's language, and nothing overflows at the
  default text size or at twice that size, in German and in the pseudo-locale
  (longer strings with accents).

  Background:
    Given the backend serves {'trivia.default'}
    And the backend serves {'identity.default'}

  @T-0064-AC4 @l10n
  Scenario Outline: In German at <scale>x every page reads German and nothing overflows
    Given the device locale is {'de'}
    And the text scale is <scale>
    And I am signed in as {'reader@mini-client.test'}
    When I open the trivia
    Then I see {'Kategorie'}
    And I see {'Schwierigkeit'}
    And I see {'Bestwert 870'}
    And nothing overflows
    When I start the round
    And I answer {'W'} after {1000} milliseconds
    Then I see {'Frage 1 von 10'}
    And the question shows {'Falsch'}
    And nothing overflows
    When I go to the next question
    And I play the answers {'C0 W0x8'}
    Then I see {'Ergebnis'}
    And I see {'1 von 10 richtig'}
    And I see {'Bestwert: 870'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0064-AC4 @l10n
  Scenario Outline: In the pseudo-locale at <scale>x nothing overflows on any page
    Given the pseudo-locale is active
    And the text scale is <scale>
    When I open the trivia
    Then I see {'[Çàţéĝóŕý ~~~]'}
    And nothing overflows
    When I start the round
    And I answer {'C'} after {1000} milliseconds
    Then nothing overflows
    When I go to the next question
    And I play the answers {'W0 N0 W0x7'}
    Then I see {'[Šàṽé ýóúŕ šçóŕé ~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0064-AC4 @l10n
  Scenario: In German the quit dialog reads German
    Given the device locale is {'de'}
    When I open the round {'all'} {'easy'} of seed {42}
    And I ask to quit the round
    Then I see {'Diese Runde beenden?'}
    And I see {'Weiterspielen'}
    And nothing overflows
