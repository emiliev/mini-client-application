Feature: Search as you type
  The search waits until typing pauses, sends one request for what was
  typed, shows only the latest query's answer, and remembers what was found.

  Background:
    Given the backend serves {'discovery.default'}

  @T-0046-AC6 @smoke
  Scenario: Typing one character at a time sends one request, for the whole word
    When I open the search
    And I type {'spi'} one character at a time
    Then the backend received {0} requests for {'GET /v1/search'}
    When {299} milliseconds pass
    Then the backend received {0} requests for {'GET /v1/search'}
    When {1} milliseconds pass
    Then the backend received {1} requests for {'GET /v1/search'}
    And the backend received {'GET /v1/search?q=spi'}
    When {500} milliseconds pass
    Then the results show the characters section, then the comics section
    And the characters section shows the first {5} characters for {'spi'} with their art
    And the comics section shows the first {5} comics for {'spi'} with their art

  @T-0046-AC6
  Scenario: A pause inside the word sends a request for each pause
    When I open the search
    And I type {'sp'} one character at a time
    And {300} milliseconds pass
    And I type {'spi'} one character at a time
    And {300} milliseconds pass
    Then the backend received {2} requests for {'GET /v1/search'}
    And the backend received {'GET /v1/search?q=sp'}
    And the backend received {'GET /v1/search?q=spi'}

  @T-0046-AC6
  Scenario: A slow answer for an older query does not replace the newer one's
    When I open the search
    Given the backend holds {'GET /v1/search?q=spire'}
    When I type {'spire'}
    And the app sends {'GET /v1/search?q=spire'}
    And I type {'spin'}
    Then the characters section shows the first {5} characters for {'spin'} with their art
    When the backend releases {'GET /v1/search?q=spire'}
    Then the characters section shows the first {5} characters for {'spin'} with their art
    And I don't see {'Spire Alchemist'}
    And the field reads {'spin'}
    And the backend received {2} requests for {'GET /v1/search'}

  @T-0046-AC6
  Scenario: Answers that arrive in reverse order end on the newer query's
    When I open the search
    Given the backend holds {'GET /v1/search?q=spire'}
    And the backend holds {'GET /v1/search?q=spin'}
    When I type {'spire'}
    And the app sends {'GET /v1/search?q=spire'}
    And I type {'spin'}
    And the app sends {'GET /v1/search?q=spin'}
    And the backend releases {'GET /v1/search?q=spin'}
    Then the characters section shows the first {5} characters for {'spin'} with their art
    When the backend releases {'GET /v1/search?q=spire'}
    Then the characters section shows the first {5} characters for {'spin'} with their art
    And I don't see {'Spire Alchemist'}

  @T-0046-AC6
  Scenario: Clearing the field while a request is in flight shows the recent searches
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    Given the backend holds {'GET /v1/search?q=spi'}
    When I type {'spi'}
    And the app sends {'GET /v1/search?q=spi'}
    And I tap the icon button {'Clear search'}
    Then the recent searches are {'amber'}
    When the backend releases {'GET /v1/search?q=spi'}
    And the app finishes writing to storage
    Then the recent searches are {'amber'}
    And I don't see {'Spindle Alchemist'}
    And the field reads {''}

  @T-0046-AC6
  Scenario: Shortening the query while a request is in flight drops its answer
    When I open the search
    Given the backend holds {'GET /v1/search?q=spi'}
    When I type {'spi'}
    And the app sends {'GET /v1/search?q=spi'}
    And I type {'s'}
    And the backend releases {'GET /v1/search?q=spi'}
    Then I don't see {'Spindle Alchemist'}
    And I see {'Search for characters and comics by name.'}
    And the backend received {1} requests for {'GET /v1/search'}

  @T-0046-AC6
  Scenario: The searches that found something are remembered, most recent first, without repeats, at most 10
    When I open the search
    And I search for each of {'spi, amber, chron, ard, co, spire, marble, bard, ma, zzzz, neon, frost, spi'}
    And the app finishes writing to storage
    And I tap the icon button {'Clear search'}
    Then the recent searches are {'spi, frost, neon, ma, bard, marble, spire, co, ard, chron'}

  @T-0046-AC6
  Scenario: The recent searches survive a new search flow
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    Then the recent searches are {'spi, amber'}
    And the backend received {2} requests for {'GET /v1/search'}

  @T-0046-AC6
  Scenario: Tapping a recent search searches it at once
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    And I tap the recent search {'amber'}
    Then the backend received {2} requests for {'GET /v1/search?q=amber'}
    And the field reads {'amber'}
    When {0} milliseconds pass
    Then the characters section shows the first {5} characters for {'amber'} with their art
    When {300} milliseconds pass
    Then the backend received {2} requests for {'GET /v1/search?q=amber'}

  @T-0046-AC6
  Scenario: Clear forgets the recent searches, also for the next search flow
    When I open the search
    And I search for each of {'amber, spi'}
    And the app finishes writing to storage
    And I open the search again
    And I tap {'Clear'}
    Then I see {'Search for characters and comics by name.'}
    When the app finishes writing to storage
    And I open the search again
    Then I see {'Search for characters and comics by name.'}
    And I don't see {'Recent searches'}

  @T-0046-AC6
  Scenario: Clearing the recent searches while a search is being saved forgets that one too
    When I open the search
    And I type {'spi'}
    And the app finishes writing to storage
    # The save of "amber" is still on its way to storage (real I/O).
    And I type {'amber'}
    And I tap the icon button {'Clear search'}
    Then the recent searches are {'spi'}
    When I tap {'Clear'}
    And the app finishes writing to storage
    Then I see {'Search for characters and comics by name.'}
    When I open the search again
    Then I see {'Search for characters and comics by name.'}

  @T-0046-AC6
  Scenario: A search that cannot be saved still shows its results and keeps the recent searches
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    Given the app can no longer write to storage
    When I type {'spi'}
    And the app finishes writing to storage
    Then the characters section shows the first {5} characters for {'spi'} with their art
    When I tap the icon button {'Clear search'}
    Then the recent searches are {'amber'}

  @T-0046-AC6
  Scenario: A save that fails while the stored searches are still being read keeps them
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    # A new flow reads the stored searches while its linked query is searched
    # and its save fails.
    And I open the search for {'spi'} without waiting
    Given the app can no longer write to storage
    When the app finishes writing to storage
    Then the characters section shows the first {5} characters for {'spi'} with their art
    When I tap the icon button {'Clear search'}
    Then the recent searches are {'amber'}

  @T-0046-AC6
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

  @T-0046-AC4 @l10n
  Scenario: A Clear that fails explains itself in German
    Given the device locale is {'de'}
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    And I open the search again
    Given the app can no longer write to storage
    When I tap {'Löschen'}
    And the app finishes writing to storage
    Then I see {'Deine letzten Suchen konnten nicht gelöscht werden. Bitte versuche es erneut.'}
    And nothing overflows
