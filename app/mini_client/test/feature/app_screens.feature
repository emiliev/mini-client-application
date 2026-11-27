Feature: Screen tracking in the app
  Every screen that opens in the real app (its router, its wirings, its root
  container) is tracked once with its route name, and nothing else is tracked
  on the way.

  Background:
    Given the backend serves {'characters.default'}

  @T-0053-AC4 @smoke
  Scenario: Opening the app tracks home
    When I open the app
    Then the screen {'home'} was tracked
    And no analytics event was tracked

  @T-0053-AC4
  Scenario: Opening the characters list tracks its screen
    When I open the app
    And I tap {'Characters'}
    Then I see {'Characters'}
    And the screen {'characters_list'} was tracked
    And no analytics event was tracked

  @T-0053-AC4
  Scenario: Going back to home tracks home again
    When I open the app
    And I tap {'Characters'}
    And I swipe back
    Then the screen {'home'} was tracked
    And the screen {'characters_list'} was tracked
