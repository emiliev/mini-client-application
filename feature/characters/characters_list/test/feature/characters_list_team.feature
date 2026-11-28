Feature: The characters list for one team
  A list opened with a team id shows that team's characters, in name order.

  Background:
    Given the backend serves {'characters.default'}

  @T-0071-AC3
  Scenario: A list opened with a team shows only that team's characters
    When I open the characters list for team {'harbor-watch'}
    Then the backend received {1} requests for {'GET /v1/characters?team=harbor-watch&offset=0&limit=30'}
    And the characters list shows the first {30} characters of team {'Harbor Watch'}

  @T-0071-AC3
  Scenario: A list opened with an id no team has is empty, not the whole cast
    When I open the characters list for team {'red'}
    Then I see {'No characters yet'}
