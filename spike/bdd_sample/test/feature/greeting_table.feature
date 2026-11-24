@T-0029-AC4
Feature: Greeting texts
  A Gherkin data table reaches the step as mc_test_steps' DataTable.

  Scenario: Every label is on screen
    Given the backend serves {'greeting.basic'}
    When I open the greeting
    Then I see the texts
      | 'text'         |
      | 'Hello, Bazel' |
      | 'Say goodbye'  |
