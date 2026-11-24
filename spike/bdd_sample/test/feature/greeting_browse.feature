Feature: Greeting
  The sample says hello through the doubled backend.

  Background:
    Given the backend serves {'greeting.basic'}

  @T-0001-AC1 @smoke
  Scenario: The greeting is shown
    When I open the greeting
    Then I see {'Hello, Bazel'}

  @T-0029-AC1
  Scenario: Tapping the button says goodbye
    When I open the greeting
    And I tap {'Say goodbye'}
    Then I see {'Goodbye'}
    And I don't see {'Hello, Bazel'}
