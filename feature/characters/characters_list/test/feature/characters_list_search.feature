Feature: Opening the search from the characters list
  The app bar's search action hands over to the character search.

  Background:
    Given the backend serves {'characters.default'}

  @T-0071-AC4
  Scenario: The search action asks the app to open the search exactly once
    When I open the characters list
    And I tap the icon button {'Search characters'}
    Then the app was asked to open the search

  @T-0071-AC4
  Scenario: A double tap on the search action opens it once
    When I open the characters list
    And I tap the icon button {'Search characters'} twice in quick succession
    Then the app was asked to open the search

  @T-0071-AC4 @l10n
  Scenario: The search action is German in German and does not overflow at twice the text size
    Given the device locale is {'de'}
    And the text scale is {2}
    When I open the characters list
    And I tap the icon button {'Figuren suchen'}
    Then the app was asked to open the search
    And nothing overflows

  @T-0071-AC4 @l10n
  Scenario: The search action reads in the pseudo-locale without overflow
    Given the pseudo-locale is active
    And the text scale is {2}
    When I open the characters list
    And I tap the icon button {'[Šéàŕçĥ çĥàŕàçţéŕš ~~~~~~]'}
    Then the app was asked to open the search
    And nothing overflows
