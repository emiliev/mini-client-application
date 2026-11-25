Feature: Browse characters
  Fans see the characters in name order, preview one inside the list and
  open its full profile.

  Background:
    Given the backend serves {'characters.default'}

  @T-0032-AC1 @smoke
  Scenario: The first page lists 30 characters in name order
    When I open the characters list
    Then I see {'Characters'}
    And the backend received {'GET /v1/characters?offset=0&limit=30'}
    And I see the first {30} characters in name order with their bundled art

  @T-0032-AC2
  Scenario Outline: A failed first page explains the problem and retries
    Given the backend fails {'GET /v1/characters'} with {<failure>}
    When I open the characters list
    Then I see {'Characters could not be loaded'}
    And I see {<message>}
    When the backend recovers
    And I tap {'Retry'}
    Then I see {'Amber Alchemist'}
    And I don't see {'Characters could not be loaded'}

    Examples:
      | failure        | message                                             |
      | 'server_error' | 'The server had a problem. Please try again later.' |
      | 'timeout'      | 'The request took too long. Please try again.'      |
      | 'offline'      | 'No connection. Check your network and try again.'  |
      | 'malformed'    | 'Something went wrong.'                             |

  @T-0032-AC2
  Scenario: A failed second page keeps the loaded characters and offers Retry
    Given the backend fails {'GET /v1/characters?offset=30'} with {'server_error'}
    When I open the characters list
    And I scroll the characters list to the end
    Then I see {'Could not load more characters.'}
    And I see {'Retry'}
    And the characters list shows {30} characters
    When the backend recovers
    And I tap {'Retry'}
    Then the characters list shows {60} characters
    And I don't see {'Could not load more characters.'}

  @T-0032-AC3
  Scenario: Tapping a character opens its preview inside the flow
    When I open the characters list
    And I tap {'Amber Alchemist'}
    Then I see the character preview for {'Amber Alchemist'}
    And I see {'See full profile'}

  @T-0032-AC3
  Scenario: The full profile hands over to the app exactly once
    When I open the characters list
    And I tap {'Amber Alchemist'}
    And I tap {'See full profile'}
    Then the app was asked to open character {'Amber Alchemist'}

  @T-0032-AC3
  Scenario: Going back from the preview keeps the list where I left it
    When I open the characters list
    And I scroll the characters list until I see {'Amber Herald'}
    And I tap {'Amber Herald'}
    Then I see the character preview for {'Amber Herald'}
    When I swipe back
    Then I don't see the character preview
    And the characters list keeps its scroll position
    And I see {'Amber Herald'}
    And the characters list shows {30} characters
    And the backend received {1} requests for {'GET /v1/characters'}

  @T-0032-AC4 @l10n
  Scenario: In German the title and the preview button come from the German strings
    Given the device locale is {'de'}
    When I open the characters list
    Then I see {'Figuren'}
    When I tap {'Amber Alchemist'}
    Then I see {'Vollständiges Profil ansehen'}

  @T-0032-AC4 @l10n
  Scenario: The pseudo-locale renders the list and the preview without overflow
    Given the pseudo-locale is active
    When I open the characters list
    Then I see {'[Çĥàŕàçţéŕš ~~~~]'}
    And nothing overflows
    When I tap {'Amber Alchemist'}
    Then I see {'[Šéé fúļļ þŕófíļé ~~~~~~~]'}
    And nothing overflows
