Feature: Missing steps
  @T-0029-AC2
  Scenario: Nobody wrote these steps
    Given the moon is made of cheese
    When I tap {'Launch'}
    Then I count {3} craters
