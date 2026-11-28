Feature: Open a result and read the search in other languages
  Tapping a result hands the character over to the app, once. The search
  reads well in German, in the pseudo-locale and at large text sizes.

  Background:
    Given the backend serves {'characters.default'}

  @T-0071-AC4
  Scenario: Tapping a result hands the character over to the app exactly once
    When I open the search
    And I type {'spi'}
    And I tap the result {'Spindle Alchemist'}
    Then the app was asked to open character {'Spindle Alchemist'}

  @T-0071-AC4
  Scenario: A double tap on a result hands it over once
    When I open the search
    And I type {'spi'}
    And I tap the result {'Spindle Alchemist'} twice in quick succession
    Then the app was asked to open character {'Spindle Alchemist'}

  @T-0071-AC4
  Scenario: A second tap 499 ms after the first is still the same tap
    When I open the search
    And I type {'spi'}
    And I tap the result {'Spindle Alchemist'} and again after {499} milliseconds
    Then the app was asked to open character {'Spindle Alchemist'}

  @T-0071-AC4
  Scenario: A tap 501 ms after the first opens the result again
    When I open the search
    And I type {'spi'}
    And I tap the result {'Spindle Alchemist'} and again after {501} milliseconds
    Then the app was asked to open character {'Spindle Alchemist'} {2} times

  @T-0071-AC4
  Scenario: A result deep in the list, after a page was loaded, opens that character
    When I open the search
    And I type {'amber'}
    And I scroll the results to the end
    And I tap the result {'Amber Wanderer'}
    Then the app was asked to open character {'Amber Wanderer'}

  @T-0071-AC4 @l10n
  Scenario Outline: In German the field, the facets and the states are German at 1 and 2 times the text size
    Given the device locale is {'de'}
    And the text scale is {<scale>}
    When I open the search
    Then I see {'Suche'}
    And I see {'Figuren nach Namen suchen'}
    And I see {'Suche Figuren nach dem Anfang ihres Namens.'}
    And nothing overflows
    When I type {'spi'}
    Then I see {'Name A–Z'}
    And I see {'Zuletzt aktualisiert'}
    And the results show the first {5} characters for {'spi'}
    And nothing overflows
    When I tap the team chip {'The Undertow'}
    And I type {'zzzz'}
    Then I see {'Keine Figuren gefunden'}
    And I see {'Keine Figur von The Undertow hat einen Namen, der mit „zzzz“ beginnt. Versuche ein anderes Team oder einen anderen Namen.'}
    And nothing overflows
    Given the backend fails {'GET /v1/characters'} with {'server_error'}
    When I type {'spi'}
    Then I see {'Die Suche ist fehlgeschlagen'}
    And I see {'Erneut versuchen'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0071-AC4 @l10n
  Scenario: In German the recent searches are German
    Given the device locale is {'de'}
    When I open the search
    And I type {'spi'}
    And the app finishes writing to storage
    And I tap the icon button {'Suche löschen'}
    Then I see {'Letzte Suchen'}
    And I see {'Löschen'}
    And nothing overflows

  @T-0071-AC4 @l10n
  Scenario Outline: The pseudo-locale renders every state without overflow at 1 and 2 times the text size
    Given the pseudo-locale is active
    And the text scale is {<scale>}
    When I open the search
    Then I see {'[Šéàŕçĥ çĥàŕàçţéŕš ƀý ñàɱé ~~~~~~~~~~]'}
    And I see {'[Šéàŕçĥ ƒóŕ çĥàŕàçţéŕš ƀý ţĥé šţàŕţ óƒ ţĥéíŕ ñàɱé. ~~~~~~~~~~~~~~~~~~~~]'}
    And nothing overflows
    When I type {'spi'}
    Then I see {'[Ñàɱé À–Ž ~~~]'}
    And the results show the first {5} characters for {'spi'}
    And nothing overflows
    When I tap the team chip {'Open Road'}
    And I type {'zzzz'}
    Then I see {'[Ñó çĥàŕàçţéŕš ƒóúñð ~~~~~~~~]'}
    And nothing overflows
    Given the backend fails {'GET /v1/characters'} with {'server_error'}
    When I type {'spi'}
    Then I see {'[Ţĥé šéàŕçĥ ƒàíļéð ~~~~~~~]'}
    And nothing overflows
    And the app finishes writing to storage
    When I tap the icon button {'[Çļéàŕ šéàŕçĥ ~~~~~]'}
    Then I see {'[Ŕéçéñţ šéàŕçĥéš ~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |
