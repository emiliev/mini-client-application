Feature: A character's profile
  Fans open one character and read its profile section by section: the
  portrait and names, the biography, the power stats, the comics it appears
  in and the details, each leading on.

  Background:
    # The comics domain answers the "Comics" row (GET /v1/comics?characterId=);
    # the strict harness fails any request to a route nothing serves.
    Given the backend serves {'characters.default'}
    And the backend serves {'comics.default'}

  @T-0067-AC1 @smoke
  Scenario: The profile shows the header, the bio, the stats, the comics and the favourite
    When I open character {100002}
    Then the backend received {'GET /v1/characters/100002'}
    And I see the header of character {100002} with its bundled portrait
    And I see {'Also known as The Sentinel'}
    And I see {'Add to favourites'}
    And I see {'Biography'}
    And I see the bio of character {100002}
    And I see {'Power stats'}
    And the stats chart shows the stats of character {100002}
    And I scroll the profile until I see {'Comics'}
    And the comics row lists the comics of character {100002}
    And the backend received {1} requests for {'GET /v1/characters/100002'}
    And the backend received {1} requests for {'GET /v1/comics'}

  @T-0067-AC1
  Scenario: The details name the origin, the team, the first appearance and the powers
    When I open character {100002}
    And I scroll the profile until I see {'Details'}
    Then the fact {'Origin'} reads {'a clockmaker\'s daughter'}
    And the fact {'Team'} reads {'The Undertow'}
    And the fact {'First appeared'} reads {'1984'}
    And the fact {'Powers'} reads {'Frost breath, Memory reading, Tidal command'}

  @T-0067-AC1
  Scenario: A character with no aliases shows no aliases line
    When I open character {100000}
    Then I see the header of character {100000} with its bundled portrait
    And I don't see {'Also known as'}
    And the stats chart shows the stats of character {100000}

  @T-0067-AC1
  Scenario: A character no comic features says so instead of showing a row
    When I open character {101187}
    Then I see the header of character {101187} with its bundled portrait
    When I scroll the profile until I see {'No comics yet.'}
    Then there is no comics row
    And the backend received {1} requests for {'GET /v1/comics'}

  @T-0067-AC2
  Scenario Outline: A failed character explains the problem and retries
    Given the backend fails {'GET /v1/characters/100002'} with {<failure>}
    When I open character {100002}
    Then I see {'The character could not be loaded'}
    And I see {<message>}
    When the backend recovers
    And I tap {'Retry'}
    Then I see the header of character {100002} with its bundled portrait
    And I don't see {'The character could not be loaded'}

    Examples:
      | failure        | message                                             |
      | 'server_error' | 'The server had a problem. Please try again later.' |
      | 'timeout'      | 'The request took too long. Please try again.'      |
      | 'offline'      | 'No connection. Check your network and try again.'  |
      | 'malformed'    | 'Something went wrong.'                             |

  @T-0067-AC2
  Scenario: Failed comics fail the page, and Retry loads both again
    Given the backend fails {'GET /v1/comics'} with {'server_error'}
    When I open character {100002}
    Then I see {'The character could not be loaded'}
    And I see {'The server had a problem. Please try again later.'}
    When the backend recovers
    And I tap {'Retry'}
    Then I see the header of character {100002} with its bundled portrait
    And the backend received {2} requests for {'GET /v1/characters/100002'}
    # Three failed attempts (the client retries a failing GET twice) and the
    # answer after Retry.
    And the backend received {4} requests for {'GET /v1/comics'}

  @T-0067-AC2
  Scenario: A double Retry sends one request
    Given the backend fails {'GET /v1/characters/100002'} with {'malformed'}
    When I open character {100002}
    Then I see {'The character could not be loaded'}
    When the backend recovers
    And I tap {'Retry'} twice in quick succession
    Then I see the header of character {100002} with its bundled portrait
    And the backend received {2} requests for {'GET /v1/characters/100002'}
    And the backend received {2} requests for {'GET /v1/comics'}

  @T-0067-AC2
  Scenario: An unknown character shows that it was not found
    When I open character {999999}
    Then I see {'Character not found'}
    And I see {'This character does not exist or is no longer available.'}
    And I don't see {'Retry'}
    And nothing overflows
    And the backend received {1} requests for {'GET /v1/characters/999999'}

  @T-0067-AC2
  Scenario: An unknown character is not found even when the comics fail
    Given the backend fails {'GET /v1/comics'} with {'server_error'}
    When I open character {999999}
    Then I see {'Character not found'}
    And I don't see {'The character could not be loaded'}

  @T-0067-AC3
  Scenario: Tapping a comic hands it over to the app exactly once
    When I open character {100002}
    And I tap the comic {'Brass Crossing #8'}
    Then the app was asked to open comic {'Brass Crossing #8'}

  @T-0067-AC3
  Scenario: A double tap on a comic hands it over once (P-089)
    When I open character {100002}
    And I tap the comic {'Brass Crossing #8'} twice in quick succession
    Then the app was asked to open comic {'Brass Crossing #8'}

  @T-0067-AC3
  Scenario: A second tap 499 ms after the first is still the same tap (P-089)
    When I open character {100002}
    And I tap the comic {'Brass Crossing #8'} and again after {499} milliseconds
    Then the app was asked to open comic {'Brass Crossing #8'}

  @T-0067-AC3
  Scenario: A tap 501 ms after the first opens the comic again (P-089)
    When I open character {100002}
    And I tap the comic {'Brass Crossing #8'} and again after {501} milliseconds
    Then the app was asked to open comic {'Brass Crossing #8'} {2} times

  @T-0067-AC3
  Scenario: Tapping a different comic 450 ms later is not a double tap (P-089)
    When I open character {100002}
    And I tap the comic {'Brass Crossing #8'} and then {'Cinder Reckoning #2'} after {450} milliseconds
    Then the app was asked to open comics {'Brass Crossing #8'} and {'Cinder Reckoning #2'}

  @T-0067-AC4 @l10n
  Scenario: In German the sections and labels are German
    Given the device locale is {'de'}
    When I open character {100002}
    Then I see {'Auch bekannt als The Sentinel'}
    And I see {'Zu Favoriten hinzufügen'}
    And I see {'Biografie'}
    And I see {'Kraftwerte'}
    And the stats chart reads {'Kraftwerte von Spiral Warden'} then {'Intelligenz: 72, Stärke: 93, Tempo: 10, Robustheit: 26, Energie: 93, Kampfkraft: 68'}
    When I scroll the profile until I see {'Angaben'}
    Then the fact {'Herkunft'} reads {'a clockmaker\'s daughter'}
    And the fact {'Erster Auftritt'} reads {'1984'}
    And the fact {'Kräfte'} reads {'Frost breath, Memory reading, Tidal command'}

  @T-0067-AC4 @l10n
  Scenario: The stats chart reads each stat in English for a screen reader
    When I open character {100002}
    Then the stats chart reads {'Power stats of Spiral Warden'} then {'Intelligence: 72, Strength: 93, Speed: 10, Durability: 26, Energy: 93, Combat: 68'}

  @T-0067-AC4 @l10n
  Scenario: In German a failed character explains itself in German
    Given the device locale is {'de'}
    And the backend fails {'GET /v1/characters/100002'} with {'server_error'}
    When I open character {100002}
    Then I see {'Die Figur konnte nicht geladen werden'}
    And I see {'Erneut versuchen'}

  @T-0067-AC4 @l10n
  Scenario: In German an unknown character says so in German
    Given the device locale is {'de'}
    When I open character {999999}
    Then I see {'Figur nicht gefunden'}
    And I see {'Diese Figur gibt es nicht oder nicht mehr.'}

  @T-0067-AC4 @l10n
  Scenario: In German a character nobody features says so in German
    Given the device locale is {'de'}
    When I open character {101187}
    And I scroll the profile until I see {'Noch keine Comics.'}
    Then there is no comics row

  @T-0067-AC4 @l10n
  Scenario Outline: In German at <scale>x nothing overflows on any state
    Given the device locale is {'de'}
    And the text scale is <scale>
    When I open character {100002}
    Then I see {'Biografie'}
    And nothing overflows
    When I scroll the profile to the end
    Then I see {'Angaben'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0067-AC4 @l10n
  Scenario Outline: In the pseudo-locale at <scale>x nothing overflows on any section
    Given the pseudo-locale is active
    And the text scale is <scale>
    When I open character {100002}
    Then I see {'[Ɓíóĝŕàþĥý ~~~~]'}
    And I see {'[Àļšó ķñóŵñ àš The Sentinel ~~~~~~]'}
    And I see {'[Àðð ţó ƒàvóúŕíţéš ~~~~~~~]'}
    And nothing overflows
    When I scroll the profile until I see {'[Þóŵéŕ šţàţš ~~~~]'}
    Then nothing overflows
    When I scroll the profile until I see {'[Çóɱíçš ~~]'}
    Then nothing overflows
    When I scroll the profile to the end
    Then I see {'[Ðéţàíļš ~~~]'}
    And the fact {'[Óŕíĝíñ ~~]'} reads {'a clockmaker\'s daughter'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0067-AC4 @l10n
  Scenario Outline: In the pseudo-locale at <scale>x a character nobody features does not overflow
    Given the pseudo-locale is active
    And the text scale is <scale>
    When I open character {101187}
    And I scroll the profile until I see {'[Ñó çóɱíçš ýéţ. ~~~~~~]'}
    Then nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0067-AC4 @l10n
  Scenario Outline: At <scale>x the not-found and error states do not overflow in the pseudo-locale
    Given the pseudo-locale is active
    And the text scale is <scale>
    When I open character {999999}
    Then I see {'[Çĥàŕàçţéŕ ñóţ ƒóúñð ~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0067-AC4 @l10n
  Scenario Outline: At <scale>x a failed character does not overflow in the pseudo-locale
    Given the pseudo-locale is active
    And the text scale is <scale>
    And the backend fails {'GET /v1/characters/100002'} with {'server_error'}
    When I open character {100002}
    Then I see {'[Ţĥé çĥàŕàçţéŕ çóúļð ñóţ ƀé ļóàðéð ~~~~~~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |
