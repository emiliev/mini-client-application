Feature: Search as you type
  The search waits until typing pauses, sends one request for what was
  typed, shows only the latest query's answer, and remembers what was found.

  Background:
    Given the backend serves {'characters.default'}

  @T-0071-AC2 @smoke
  Scenario: Typing one character at a time sends one request, for the whole word
    When I open the search
    And I type {'spi'} one character at a time
    Then the backend received {0} requests for {'GET /v1/characters'}
    When {299} milliseconds pass
    Then the backend received {0} requests for {'GET /v1/characters'}
    When {1} milliseconds pass
    Then the backend received {1} requests for {'GET /v1/characters'}
    And the backend received {'GET /v1/characters?nameStartsWith=spi'}
    When {500} milliseconds pass
    Then the backend received {1} requests for {'GET /v1/characters'}
    And the results show the first {30} characters for {'spi'}

  @T-0071-AC2
  Scenario: The keyboard's Search key searches at once
    When I open the search
    And I type {'spi'} one character at a time
    And I press Search on the keyboard
    Then the backend received {1} requests for {'GET /v1/characters?nameStartsWith=spi'}
    When {300} milliseconds pass
    Then the backend received {1} requests for {'GET /v1/characters'}
    And the results show the first {30} characters for {'spi'}

  @T-0071-AC2
  Scenario: A pause inside the word sends a request for each pause
    When I open the search
    And I type {'sp'} one character at a time
    And {300} milliseconds pass
    And I type {'spi'} one character at a time
    And {300} milliseconds pass
    Then the backend received {2} requests for {'GET /v1/characters'}
    And the backend received {'GET /v1/characters?nameStartsWith=sp'}
    And the backend received {'GET /v1/characters?nameStartsWith=spi'}

  @T-0071-AC2
  Scenario: A slow answer for an older query does not replace the newer one's
    When I open the search
    Given the backend holds {'GET /v1/characters?nameStartsWith=spire'}
    When I type {'spire'}
    And the app sends {'GET /v1/characters?nameStartsWith=spire'}
    And I type {'spin'}
    Then the results show the first {30} characters for {'spin'}
    When the backend releases {'GET /v1/characters?nameStartsWith=spire'}
    Then the results show the first {30} characters for {'spin'}
    And I don't see {'Spire Alchemist'}
    And the field reads {'spin'}
    And the backend received {2} requests for {'GET /v1/characters?offset=0'}

  @T-0071-AC2
  Scenario: Answers that arrive in reverse order end on the newer query's
    When I open the search
    Given the backend holds {'GET /v1/characters?nameStartsWith=spire'}
    And the backend holds {'GET /v1/characters?nameStartsWith=spin'}
    When I type {'spire'}
    And the app sends {'GET /v1/characters?nameStartsWith=spire'}
    And I type {'spin'}
    And the app sends {'GET /v1/characters?nameStartsWith=spin'}
    And the backend releases {'GET /v1/characters?nameStartsWith=spin'}
    Then the results show the first {30} characters for {'spin'}
    When the backend releases {'GET /v1/characters?nameStartsWith=spire'}
    Then the results show the first {30} characters for {'spin'}
    And I don't see {'Spire Alchemist'}

  @T-0071-AC2
  Scenario: Clearing the field while a request is in flight shows the recent searches
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    Given the backend holds {'GET /v1/characters?nameStartsWith=spi'}
    When I type {'spi'}
    And the app sends {'GET /v1/characters?nameStartsWith=spi'}
    And I tap the icon button {'Clear search'}
    Then the recent searches are {'amber'}
    When the backend releases {'GET /v1/characters?nameStartsWith=spi'}
    And the app finishes writing to storage
    Then the recent searches are {'amber'}
    And I don't see {'Spindle Alchemist'}
    And the field reads {''}

  @T-0071-AC2
  Scenario: Changing the query while a request is in flight drops the old answer, and the old query is not saved
    When I open the search
    Given the backend holds {'GET /v1/characters?nameStartsWith=spi'}
    When I type {'spi'}
    And the app sends {'GET /v1/characters?nameStartsWith=spi'}
    And I tap the icon button {'Clear search'}
    And the backend releases {'GET /v1/characters?nameStartsWith=spi'}
    And the app finishes writing to storage
    Then I don't see {'Spindle Alchemist'}
    And I see {'Search for characters by the start of their name.'}
    And the backend received {1} requests for {'GET /v1/characters'}

  @T-0071-AC2
  Scenario: The searches that found something are remembered, most recent first, without repeats, at most 10
    When I open the search
    And I search for each of {'spi, amber, brass, zzzz, cinder, dusk, ember, frost, gale, hollow, iron, jade, kestrel, spi'}
    And the app finishes writing to storage
    And I tap the icon button {'Clear search'}
    Then the recent searches are {'spi, kestrel, jade, iron, hollow, gale, frost, ember, dusk, cinder'}

  @T-0071-AC2
  Scenario: The recent searches survive a new search flow
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    Then the recent searches are {'spi, amber'}
    And the backend received {2} requests for {'GET /v1/characters'}

  @T-0071-AC2
  Scenario: Tapping a recent search searches it at once
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    And I tap the recent search {'amber'}
    Then the backend received {2} requests for {'GET /v1/characters?nameStartsWith=amber'}
    And the field reads {'amber'}
    When {0} milliseconds pass
    Then the results show the first {30} characters for {'amber'}
    When {300} milliseconds pass
    Then the backend received {2} requests for {'GET /v1/characters?nameStartsWith=amber&offset=0'}

  @T-0071-AC2
  Scenario: A facet change does not save the query again
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    And I tap the sort chip {'Name Z–A'}
    And the app finishes writing to storage
    And I tap the icon button {'Clear search'}
    Then the recent searches are {'amber'}

  @T-0071-AC2
  Scenario: Clear forgets the recent searches, also for the next search flow
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    And I tap {'Clear'}
    Then I see {'Search for characters by the start of their name.'}
    When the app finishes writing to storage
    And I open the search again
    Then I see {'Search for characters by the start of their name.'}
    And I don't see {'Recent searches'}

  @T-0071-AC2
  Scenario: A search that cannot be saved still shows its results and keeps the recent searches
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    Given the app can no longer write to storage
    When I type {'spi'}
    And the app finishes writing to storage
    Then the results show the first {30} characters for {'spi'}
    When I tap the icon button {'Clear search'}
    Then the recent searches are {'amber'}

  @T-0071-AC2
  Scenario: A Clear that fails keeps the recent searches and says so
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    Given the app can no longer write to storage
    When I tap {'Clear'}
    And the app finishes writing to storage
    Then the recent searches are {'spi, amber'}
    And I see {'Your recent searches could not be cleared. Please try again.'}
    When I open the search again
    Then the recent searches are {'spi, amber'}
    And I don't see {'Your recent searches could not be cleared. Please try again.'}
