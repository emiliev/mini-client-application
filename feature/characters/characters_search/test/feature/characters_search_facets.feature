Feature: Sort, narrow and page the matches
  Fans choose how the matches are sorted and which team they belong to, and
  the list loads more matches as they scroll.

  Background:
    Given the backend serves {'characters.default'}

  @T-0071-AC3
  Scenario Outline: A sort change sends one request and shows that order from the top
    When I open the search
    And I type {'amber'}
    Then the sort {'Name A–Z'} is chosen
    When I tap the sort chip {<label>}
    Then the backend received {2} requests for {'GET /v1/characters'}
    And the backend received {1} requests for {'GET /v1/characters?nameStartsWith=amber&orderBy=<order>&offset=0&limit=30'}
    And the sort {<label>} is chosen
    And the results show the first {30} characters for {'amber'} sorted by {'<order>'}

    Examples:
      | label                    | order     |
      | 'Name Z–A'               | -name     |
      | 'Recently updated'       | -modified |
      | 'Least recently updated' | modified  |

  @T-0071-AC3
  Scenario: Sorting again by the first order sends one request for it
    When I open the search
    And I type {'amber'}
    And I tap the sort chip {'Name Z–A'}
    And I tap the sort chip {'Name A–Z'}
    Then the backend received {2} requests for {'GET /v1/characters?orderBy=name'}
    And the backend received {1} requests for {'GET /v1/characters?orderBy=-name'}
    And the results show the first {30} characters for {'amber'}

  @T-0071-AC3
  Scenario: A sort change starts the paging over
    When I open the search
    And I type {'amber'}
    And I scroll the results until the next page loads
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=amber&orderBy=name&offset=30&limit=30'}
    When I tap the sort chip {'Name Z–A'}
    Then the backend received {1} requests for {'GET /v1/characters?orderBy=-name&offset=0'}
    And the backend received {0} requests for {'GET /v1/characters?orderBy=-name&offset=30'}
    And the backend received {3} requests for {'GET /v1/characters'}
    And the results show the first {30} characters for {'amber'} sorted by {'-name'}

  @T-0071-AC3
  Scenario: A team keeps only its characters, and choosing it again lets every team show
    When I open the search
    And I type {'amber'}
    And I tap the team chip {'Harbor Watch'}
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=amber&orderBy=name&team=Harbor%20Watch&offset=0&limit=30'}
    And the team {'Harbor Watch'} is chosen
    And the results show the first {8} characters for {'amber'} of team {'Harbor Watch'}
    When I tap the team chip {'Harbor Watch'}
    Then no team is chosen
    And the backend received {3} requests for {'GET /v1/characters'}
    And the backend received {1} requests for {'GET /v1/characters?team=Harbor%20Watch'}
    And the results show the first {30} characters for {'amber'}

  @T-0071-AC3
  Scenario: A team and a sort combine
    When I open the search
    And I type {'spi'}
    And I tap the team chip {'The Undertow'}
    And I tap the sort chip {'Name Z–A'}
    Then the backend received {'GET /v1/characters?nameStartsWith=spi&orderBy=-name&team=The%20Undertow&offset=0'}
    And the results show the first {13} characters for {'spi'} of team {'The Undertow'} sorted by {'-name'}

  @T-0071-AC3
  Scenario: A team nobody in the matches belongs to says so, and its chip brings the matches back
    When I open the search
    And I type {'ember'}
    And I tap the team chip {'Harbor Watch'}
    Then I see {'No characters found'}
    And I see {'No character of Harbor Watch has a name that starts with “ember”. Try another team or name.'}
    And the team {'Harbor Watch'} is chosen
    When I tap the team chip {'Harbor Watch'}
    Then the results show the first {30} characters for {'ember'}

  @T-0071-AC3
  Scenario: The chosen facets stay for the next query
    When I open the search
    And I type {'amber'}
    And I tap the sort chip {'Name Z–A'}
    And I tap the team chip {'Harbor Watch'}
    And I type {'brass'}
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=brass&orderBy=-name&team=Harbor%20Watch&offset=0'}
    And the results show the first {5} characters for {'brass'} of team {'Harbor Watch'} sorted by {'-name'}
    And the sort {'Name Z–A'} is chosen
    And the team {'Harbor Watch'} is chosen

  @T-0071-AC3
  Scenario: Scrolling to the end of a page loads the next one, once, and the last page ends the list
    When I open the search
    And I type {'amber'}
    And I scroll the results to the end
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=amber&orderBy=name&offset=30&limit=30'}
    And the backend received {2} requests for {'GET /v1/characters'}
    And the results show the first {38} characters for {'amber'}
    When I scroll the results to the end
    Then the backend received {2} requests for {'GET /v1/characters'}

  @T-0071-AC3
  Scenario: A short list asks for no further page
    When I open the search
    And I type {'spire w'}
    And I scroll the results to the end
    Then the backend received {1} requests for {'GET /v1/characters'}
    And the results show the first {4} characters for {'spire w'}

  @T-0071-AC3
  Scenario Outline: A failed search explains the problem, and Retry searches the same query again
    Given the backend fails {'GET /v1/characters'} with {<failure>}
    When I open the search
    And I type {'spi'}
    Then I see {'The search failed'}
    And I see {<message>}
    And {1} errors were reported
    And I see {'Name A–Z'}
    When the backend recovers
    And I tap {'Retry'}
    Then the results show the first {30} characters for {'spi'}
    And I don't see {'The search failed'}
    And the backend received {'GET /v1/characters?nameStartsWith=spi&orderBy=name&offset=0&limit=30'}

    Examples:
      | failure        | message                                             |
      | 'server_error' | 'The server had a problem. Please try again later.' |
      | 'timeout'      | 'The request took too long. Please try again.'      |
      | 'offline'      | 'No connection. Check your network and try again.'  |
      | 'malformed'    | 'Something went wrong.'                             |

  @T-0071-AC3
  Scenario: A double Retry sends one request
    Given the backend fails {'GET /v1/characters'} with {'malformed'}
    When I open the search
    And I type {'spi'}
    Then I see {'The search failed'}
    When the backend recovers
    And I tap {'Retry'} twice in quick succession
    Then the backend received {2} requests for {'GET /v1/characters?nameStartsWith=spi&offset=0'}
    And the results show the first {30} characters for {'spi'}

  @T-0071-AC3
  Scenario: A failed second page keeps the loaded characters and offers Retry
    Given the backend fails {'GET /v1/characters?offset=30'} with {'server_error'}
    When I open the search
    And I type {'amber'}
    And I scroll the results to the end
    Then I see {'Could not load more characters.'}
    And I see {'Retry'}
    When the backend recovers
    And I tap {'Retry'}
    Then the results show the first {38} characters for {'amber'}
    And I don't see {'Could not load more characters.'}

  @T-0071-AC3
  Scenario: A failed facet change shows the failure, and Retry brings that order back
    When I open the search
    And I type {'amber'}
    Given the backend fails {'GET /v1/characters?orderBy=-name'} with {'server_error'}
    When I tap the sort chip {'Name Z–A'}
    Then I see {'The search failed'}
    And the sort {'Name Z–A'} is chosen
    When the backend recovers
    And I tap {'Retry'}
    Then the results show the first {30} characters for {'amber'} sorted by {'-name'}
