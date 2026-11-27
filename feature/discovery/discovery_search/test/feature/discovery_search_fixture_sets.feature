Feature: Search over the discovery fixture sets
  The failing and the empty backends of the search, as the fixture sets
  serve them (each set serves both search routes).

  @T-0046-AC2
  Scenario: Given the server_error set, a search shows the error with Retry
    Given the backend serves {'discovery.server_error'}
    When I open the search
    And I type {'spi'}
    Then I see {'The search failed'}
    And I see {'The server had a problem. Please try again later.'}
    And I see {'Retry'}
    When I tap {'Retry'}
    Then I see {'The search failed'}
    And the backend answered {'GET /v1/search'} with {500}

  @T-0046-AC2
  Scenario: Given the empty set, every name finds nothing
    Given the backend serves {'discovery.empty'}
    When I open the search
    And I type {'spi'}
    Then I see {'No results'}
    And I see {'Nothing matches “spi”. Check the spelling or try another name.'}
    And I don't see {'Retry'}
    And the backend received {1} requests for {'GET /v1/search?q=spi'}
