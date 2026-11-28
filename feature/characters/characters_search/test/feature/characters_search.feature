Feature: Search characters by name
  Fans type the start of a name and see the characters that match, sorted by
  name, with their art, and open one.

  Background:
    # Only the characters domain: the strict harness fails any request to a
    # route nothing serves (opening a result is the app's business).
    Given the backend serves {'characters.default'}

  @T-0071-AC1 @smoke
  Scenario: Typing a prefix shows the matching characters, sorted by name, with their art
    When I open the search
    And I type {'spi'}
    Then the backend received {1} requests for {'GET /v1/characters'}
    And the backend received {'GET /v1/characters?nameStartsWith=spi&orderBy=name&offset=0&limit=30'}
    And the results show the first {30} characters for {'spi'}
    And the sort {'Name A–Z'} is chosen
    And no team is chosen

  @T-0071-AC1
  Scenario: The prefix matches in any case and is trimmed
    When I open the search
    And I type {'  SPIRE w '}
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=SPIRE%20w'}
    And the results show the first {4} characters for {'spire w'}

  @T-0071-AC1
  Scenario: A prefix nothing matches shows the empty state
    When I open the search
    And I type {'zzzz'}
    Then I see {'No characters found'}
    And I see {'No character’s name starts with “zzzz”. Check the spelling or try another name.'}
    And I don't see {'Retry'}
    And the backend received {1} requests for {'GET /v1/characters?nameStartsWith=zzzz'}
    And I see {'Name A–Z'}

  @T-0071-AC1
  Scenario: Clearing the field shows the recent searches again
    When I open the search
    And I type {'spi'}
    Then I see {'Spindle Alchemist'}
    When I type {''}
    Then I don't see {'Spindle Alchemist'}
    And I see {'Search for characters by the start of their name.'}
    And the facets are not shown

  @T-0071-AC1
  Scenario: The screen is named characters_search
    When I open the search
    Then the screen {'characters_search'} was tracked

  @T-0071-AC1
  Scenario: A search opened with a query searches it at once
    When I open the search for {'spi'} without waiting
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=spi'}
    And the field reads {'spi'}
    When {0} milliseconds pass
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=spi'}
    And the results show the first {30} characters for {'spi'}

  @T-0071-AC1
  Scenario: A search opened with a blank query opens on the recent searches
    When I open the search for {'  '}
    Then I see {'Search for characters by the start of their name.'}
    And the backend received {0} requests for {'GET /v1/characters'}
    And the facets are not shown

  @T-0071-AC1
  Scenario: A linked query is trimmed: the field and the search use the same text
    When I open the search for {' spi '} without waiting
    Then the field reads {'spi'}
    And the backend received {1} requests for {'GET /v1/characters?nameStartsWith=spi'}
    When {0} milliseconds pass
    Then the results show the first {30} characters for {'spi'}
