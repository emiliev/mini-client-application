Feature: A comic's page
  Fans open one comic and read it section by section: the cover, the
  synopsis, the facts, the creators and the cast, each leading on.

  Background:
    # Only the comics domain: the cast comes in the detail (T-0041), and the
    # strict harness fails any request to a route nothing serves.
    Given the backend serves {'comics.default'}

  @T-0041-AC1 @smoke
  Scenario: The comic shows its cover, title, issue and synopsis
    When I open comic {501500}
    Then the backend received {'GET /v1/comics/501500'}
    And I see the header of comic {501500} with its bundled cover
    And I see {'Issue #1'}
    And I see {'Synopsis'}
    And I see the synopsis of comic {501500}

  @T-0041-AC1
  Scenario: The facts are formatted for English
    When I open comic {501500}
    Then I see {'Details'}
    And the fact {'Issue'} reads {'#1'}
    And the fact {'Price'} reads {'\$3.99'}
    And the fact {'Pages'} reads {'32'}
    And the fact {'Released'} reads {'Jan 10, 1988'}

  @T-0041-AC1
  Scenario: The creators and characters sections list the comic's credits
    When I open comic {501500}
    Then the creators section lists the credits of comic {501500}
    And I see {'Esme Garrow'}
    And I see {'Cover artist'}
    And the characters section lists the cast of comic {501500}
    And I see {'Amber Vanguard'}
    And I see {'Prism Engineer'}
    And the backend received {1} requests for {'GET /v1/comics/501500'}
    And the backend received {0} requests for {'GET /v1/characters/:id'}

  @T-0041-AC2
  Scenario Outline: A failed comic explains the problem and retries
    Given the backend fails {'GET /v1/comics/501500'} with {<failure>}
    When I open comic {501500}
    Then I see {'The comic could not be loaded'}
    And I see {<message>}
    When the backend recovers
    And I tap {'Retry'}
    Then I see the header of comic {501500} with its bundled cover
    And I don't see {'The comic could not be loaded'}

    Examples:
      | failure        | message                                             |
      | 'server_error' | 'The server had a problem. Please try again later.' |
      | 'timeout'      | 'The request took too long. Please try again.'      |
      | 'offline'      | 'No connection. Check your network and try again.'  |
      | 'malformed'    | 'Something went wrong.'                             |

  @T-0041-AC2
  Scenario: A double Retry sends one request
    Given the backend fails {'GET /v1/comics/501500'} with {'malformed'}
    When I open comic {501500}
    Then I see {'The comic could not be loaded'}
    When the backend recovers
    And I tap {'Retry'} twice in quick succession
    Then I see the header of comic {501500} with its bundled cover
    And the backend received {2} requests for {'GET /v1/comics/501500'}

  @T-0041-AC2
  Scenario: An unknown comic shows that it was not found
    When I open comic {999999}
    Then I see {'Comic not found'}
    And I see {'This comic does not exist or is no longer available.'}
    And I don't see {'Retry'}
    And nothing overflows
    And the backend received {1} requests for {'GET /v1/comics/999999'}

  @T-0041-AC3
  Scenario: Tapping a character hands it over to the app exactly once
    When I open comic {501500}
    And I tap the cast member {'Amber Vanguard'}
    Then the app was asked to open character {'Amber Vanguard'}

  @T-0041-AC3
  Scenario: Tapping a creator hands them over to the app exactly once
    When I open comic {501500}
    And I tap the creator {'Esme Garrow'}
    Then the app was asked to open creator {'Esme Garrow'} of comic {501500}

  @T-0050-AC3
  Scenario: A double tap on a character hands it over once (P-089)
    When I open comic {501500}
    And I tap the cast member {'Amber Vanguard'} twice in quick succession
    Then the app was asked to open character {'Amber Vanguard'}

  @T-0050-AC3
  Scenario: A second tap 499 ms after the first is still the same tap (P-089)
    When I open comic {501500}
    And I tap the cast member {'Amber Vanguard'} and again after {499} milliseconds
    Then the app was asked to open character {'Amber Vanguard'}

  @T-0050-AC3
  Scenario: A tap 501 ms after the first opens the character again (P-089)
    When I open comic {501500}
    And I tap the cast member {'Amber Vanguard'} and again after {501} milliseconds
    Then the app was asked to open character {'Amber Vanguard'} {2} times

  @T-0050-AC3
  Scenario: A double tap on a creator hands them over once (P-089)
    When I open comic {501500}
    And I tap the creator {'Esme Garrow'} twice in quick succession
    Then the app was asked to open creator {'Esme Garrow'} of comic {501500}

  Scenario: Tapping the cover opens it full size inside the flow
    When I open comic {501500}
    And I tap the cover
    Then I see the cover page of comic {501500}
    When I swipe back
    Then I don't see the cover page
    And I see the header of comic {501500} with its bundled cover
    And the backend received {1} requests for {'GET /v1/comics/501500'}

  @T-0041-AC4 @l10n
  Scenario: In German the sections and the formats are German
    Given the device locale is {'de'}
    When I open comic {501500}
    Then I see {'Ausgabe #1'}
    And I see {'Zu Favoriten hinzufügen'}
    And I see {'Inhalt'}
    And I see {'Angaben'}
    And the fact {'Ausgabe'} reads {'#1'}
    And the fact {'Preis'} reads {'3,99 \$'}
    And the fact {'Seiten'} reads {'32'}
    And the fact {'Erschienen'} reads {'10. Jan. 1988'}
    When I scroll the comic until I see {'Mitwirkende'}
    Then I see {'Autor'}
    And I see {'Coverzeichner'}
    When I scroll the comic until I see {'Figuren'}
    Then I see {'Amber Vanguard'}

  @T-0041-AC4 @l10n
  Scenario: In German a failed comic explains itself in German
    Given the device locale is {'de'}
    And the backend fails {'GET /v1/comics/501500'} with {'server_error'}
    When I open comic {501500}
    Then I see {'Das Comic konnte nicht geladen werden'}
    And I see {'Erneut versuchen'}

  @T-0041-AC4 @l10n
  Scenario: In German an unknown comic says so in German
    Given the device locale is {'de'}
    When I open comic {999999}
    Then I see {'Comic nicht gefunden'}
    And I see {'Dieses Comic gibt es nicht oder nicht mehr.'}

  @T-0041-AC4 @l10n
  Scenario: The pseudo-locale renders every section without overflow
    Given the pseudo-locale is active
    When I open comic {501500}
    Then I see {'[Íššúé #1 ~~~~]'}
    And I see {'[Àðð ţó ƒàvóúŕíţéš ~~~~~~~]'}
    And nothing overflows
    When I scroll the comic to the end
    Then I see {'[Çĥàŕàçţéŕš ~~~~]'}
    And I see {'[Çóvéŕ àŕţíšţ ~~~~]'}
    And nothing overflows
    When I tap the cover
    Then I see the cover page of comic {501500}
    And nothing overflows

  @T-0041-AC4 @l10n
  Scenario: The pseudo-locale renders the not-found page without overflow
    Given the pseudo-locale is active
    When I open comic {999999}
    Then I see {'[Çóɱíç ñóţ ƀóúñð ~~~~~~]'}
    And nothing overflows
