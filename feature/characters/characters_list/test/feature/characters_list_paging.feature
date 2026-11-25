Feature: Characters list paging
  The list loads more characters as fans scroll, stops at the last one, and
  says so when there are none.

  @T-0032-AC5
  Scenario: Scrolling to the end of the first page loads the second once
    Given the backend serves {'characters.default'}
    When I open the characters list
    And I scroll the characters list until the next page loads
    Then the backend received {1} requests for {'GET /v1/characters?offset=30&limit=30'}
    And the backend received {2} requests for {'GET /v1/characters'}
    And the characters list shows {60} characters

  @T-0032-AC5
  Scenario: At the last page no further page is requested
    Given the backend serves {'characters.paged_45'}
    When I open the characters list
    And I scroll the characters list to the end
    Then I see {'Hero 45'}
    And the characters list shows {45} characters
    And the backend received {2} requests for {'GET /v1/characters'}
    When I scroll the characters list to the end
    Then the backend received {2} requests for {'GET /v1/characters'}

  Scenario: An empty catalogue says so
    Given the backend serves {'characters.empty'}
    When I open the characters list
    Then I see {'No characters yet'}
    And I see {'New characters will show up here.'}

  Scenario: Pulling down reloads the first page
    Given the backend serves {'characters.paged_45'}
    When I open the characters list
    And I pull to refresh
    Then the backend received {2} requests for {'GET /v1/characters?offset=0'}
    And the characters list shows {30} characters
