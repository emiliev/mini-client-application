Feature: Search characters and comics
  Fans type a name and see the characters and the comics that match, in the
  backend's ranking, narrow them to one type, and open one.

  Background:
    # Only the discovery domain: the strict harness fails any request to a
    # route nothing serves (opening a result is the app's business).
    Given the backend serves {'discovery.default'}

  @T-0046-AC1 @smoke
  Scenario: Typing a name shows its characters, then its comics, in the backend's ranking
    When I open the search
    And I type {'spi'}
    Then the backend received {1} requests for {'GET /v1/search'}
    And the backend received {'GET /v1/search?q=spi&limit=20'}
    And the results show the characters section, then the comics section
    And the characters section shows the first {5} characters for {'spi'} with their art
    And the comics section shows the first {5} comics for {'spi'} with their art
    And I see {'See all 152'}
    And I see {'See all 400'}

  @T-0046-AC1 @T-0046-AC6
  Scenario: A type chip shows one type's whole first page and sends no request
    When I open the search
    And I type {'spi'}
    And I filter by {'Comics'}
    Then the results show only the comics section
    And the comics section shows the first {20} comics for {'spi'} with their art
    And I see {'Showing 20 of 400'}
    When I filter by {'Characters'}
    Then the results show only the characters section
    And the characters section shows the first {20} characters for {'spi'} with their art
    And I see {'Showing 20 of 152'}
    When I filter by {'All'}
    Then the results show the characters section, then the comics section
    And the backend received {1} requests for {'GET /v1/search'}

  @T-0046-AC1
  Scenario: See all on a section picks its chip
    When I open the search
    And I type {'spi'}
    And I tap {'See all 400'}
    Then the results show only the comics section
    And the chip {'Comics'} is selected
    And the chip {'All'} is not selected
    And the backend received {1} requests for {'GET /v1/search'}

  @T-0046-AC1
  Scenario: The chosen chip stays for the next query
    When I open the search
    And I type {'spi'}
    And I filter by {'Characters'}
    And I type {'amber'}
    Then the results show only the characters section
    And the characters section shows the first {20} characters for {'amber'} with their art

  @T-0046-AC1
  Scenario: A name only one type has shows the other section as empty
    When I open the search
    And I type {'Spire Warden'}
    Then the characters section shows the first {1} characters for {'Spire Warden'} with their art
    And I see {'No comics match “Spire Warden”.'}
    And I don't see {'See all 1'}
    And nothing overflows

  @T-0046-AC2
  Scenario Outline: A failed search explains the problem, and Retry searches the same query again
    Given the backend fails {'GET /v1/search'} with {<failure>}
    When I open the search
    And I type {'spi'}
    Then I see {'The search failed'}
    And I see {<message>}
    When the backend recovers
    And I tap {'Retry'}
    Then the characters section shows the first {5} characters for {'spi'} with their art
    And I don't see {'The search failed'}

    Examples:
      | failure        | message                                             |
      | 'server_error' | 'The server had a problem. Please try again later.' |
      | 'timeout'      | 'The request took too long. Please try again.'      |
      | 'offline'      | 'No connection. Check your network and try again.'  |
      | 'malformed'    | 'Something went wrong.'                             |

  @T-0046-AC2
  Scenario: A double Retry sends one request
    Given the backend fails {'GET /v1/search'} with {'malformed'}
    When I open the search
    And I type {'spi'}
    Then I see {'The search failed'}
    When the backend recovers
    And I tap {'Retry'} twice in quick succession
    Then the characters section shows the first {5} characters for {'spi'} with their art
    And the backend received {2} requests for {'GET /v1/search?q=spi'}

  @T-0046-AC2
  Scenario: A name nothing matches shows that nothing was found
    When I open the search
    And I type {'zzzz'}
    Then I see {'No results'}
    And I see {'Nothing matches “zzzz”. Check the spelling or try another name.'}
    And I don't see {'Retry'}
    And the backend received {1} requests for {'GET /v1/search?q=zzzz'}

  @T-0046-AC2
  Scenario: A query under 2 characters sends no request
    When I open the search
    And I type {'s'}
    Then the backend received {0} requests for {'GET /v1/search'}
    And I see {'Search for characters and comics by name.'}
    When I type {' s '}
    Then the backend received {0} requests for {'GET /v1/search'}
    When I type {'sp'}
    Then the backend received {1} requests for {'GET /v1/search'}
    And the backend received {'GET /v1/search?q=sp'}

  @T-0046-AC2
  Scenario: Shortening the query under 2 characters hides the results
    When I open the search
    And I type {'spi'}
    Then I see {'Spindle Alchemist'}
    When I type {'s'}
    Then I don't see {'Spindle Alchemist'}
    And I see {'Search for characters and comics by name.'}
    And the backend received {1} requests for {'GET /v1/search'}

  @T-0046-AC3
  Scenario: Tapping a character hands it over to the app exactly once
    When I open the search
    And I type {'spi'}
    And I tap the result {'Spindle Alchemist'}
    Then the app was asked to open character {'Spindle Alchemist'}

  @T-0046-AC3
  Scenario: Tapping a comic hands it over to the app exactly once
    When I open the search
    And I type {'spi'}
    And I tap the result {'Spindle Chronicles #1'}
    Then the app was asked to open comic {'Spindle Chronicles #1'}

  @T-0046-AC5
  Scenario: A search opened with a query searches it once typing would have paused
    When I open the search for {'spi'}
    Then the field reads {'spi'}
    And the characters section shows the first {5} characters for {'spi'} with their art
    And the backend received {1} requests for {'GET /v1/search?q=spi'}

  @T-0046-AC4 @l10n
  Scenario: In German the field, the chips and the sections are German
    Given the device locale is {'de'}
    When I open the search
    Then I see {'Suche'}
    And I see {'Figuren und Comics suchen'}
    And I see {'Suche Figuren und Comics nach ihrem Namen.'}
    When I type {'spi'}
    Then I see {'Alle'}
    And I see {'Figuren'}
    And I see {'Comics'}
    And I see {'Alle 152 anzeigen'}
    And I see {'Alle 400 anzeigen'}
    When I filter by {'Figuren'}
    Then I see {'20 von 152 angezeigt'}
    When I type {'Spire Warden'}
    Then I see {'Keine Comics passen zu „Spire Warden“.'}

  @T-0046-AC4 @l10n
  Scenario: In German nothing found and a failure explain themselves in German
    Given the device locale is {'de'}
    When I open the search
    And I type {'zzzz'}
    Then I see {'Keine Treffer'}
    And I see {'Nichts passt zu „zzzz“. Prüfe die Schreibweise oder versuche einen anderen Namen.'}
    Given the backend fails {'GET /v1/search'} with {'server_error'}
    When I type {'spi'}
    Then I see {'Die Suche ist fehlgeschlagen'}
    And I see {'Erneut versuchen'}

  @T-0046-AC4 @l10n
  Scenario: In German the recent searches are German
    Given the device locale is {'de'}
    When I open the search
    And I type {'spi'}
    And the app finishes writing to storage
    And I tap the icon button {'Suche löschen'}
    Then I see {'Letzte Suchen'}
    And I see {'Löschen'}

  @T-0046-AC4 @l10n
  Scenario: The pseudo-locale renders every state without overflow
    Given the pseudo-locale is active
    When I open the search
    Then I see {'[Šéàŕçĥ ƀóŕ çĥàŕàçţéŕš àñð çóɱíçš ƀý ñàɱé. ~~~~~~~~~~~~~~~~]'}
    And nothing overflows
    When I type {'spi'}
    Then I see {'[Šéé àļļ 152 ~~~]'}
    And nothing overflows
    When I filter by {'[Çóɱíçš ~~]'}
    Then I see {'[Šĥóŵíñĝ 20 óƀ 400 ~~~~~]'}
    And nothing overflows
    When I type {'Spire Warden'}
    And I filter by {'[Àļļ ~]'}
    Then I see {'[Ñó çóɱíçš ɱàţçĥ “Spire Warden”. ~~~~~~~~]'}
    And nothing overflows
    When I type {'zzzz'}
    Then I see {'[Ñó ŕéšúļţš ~~~~]'}
    And nothing overflows
    And the app finishes writing to storage
    When I tap the icon button {'[Çļéàŕ šéàŕçĥ ~~~~~]'}
    Then I see {'[Ŕéçéñţ šéàŕçĥéš ~~~~~~]'}
    And nothing overflows

  @T-0046-AC4 @l10n
  Scenario: The pseudo-locale renders a failure without overflow
    Given the pseudo-locale is active
    And the backend fails {'GET /v1/search'} with {'server_error'}
    When I open the search
    And I type {'spi'}
    Then I see {'[Ţĥé šéàŕçĥ ƀàíļéð ~~~~~~~]'}
    And nothing overflows
