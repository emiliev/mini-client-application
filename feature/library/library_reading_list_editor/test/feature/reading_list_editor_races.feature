Feature: The editor stays consistent while requests are in flight
  A save, a search or a load can take a while. Meanwhile the reader may tap
  twice, go back, or the session may change: the editor sends one save,
  keeps every value, and never writes for, or hands a list to, an account
  the editing did not start in.

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'identity.default'}
    And the backend serves {'library.default'}
    And I am signed in as {'reader@mini-client.test'}

  @T-0048-AC6
  Scenario: A double Create sends one POST and completes once
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    And I tap {'Create list'} twice in quick succession
    Then the backend received {1} requests for {'POST /v1/me/lists'}
    And the editor completed with list {'l-5'}
    And the app announced {1} change to {'readingLists'}

  @T-0048-AC6
  Scenario: A double Save sends each changed part once
    When I open the reading list editor for {'l-1'}
    And I enter {'Spider-Verse Basics'} as the name
    And I tap {'Next'}
    And I tap {'Next'}
    And I move {'Amber Legacy #1'} up
    And I tap {'Save changes'} twice in quick succession
    Then the backend received {1} requests for {'PUT /v1/me/lists/l-1'}
    And the backend received {1} requests for {'PUT /v1/me/lists/l-1/items'}
    And the editor completed with list {'l-1'}

  @T-0048-AC6
  Scenario: While the save runs the buttons are off, going back is refused and nothing is lost
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I pick {'Amber Chronicles #2'}
    And I tap {'Next'}
    Given the backend holds {'POST /v1/me/lists'}
    When I tap {'Create list'}
    And the app sends {'POST /v1/me/lists'}
    Then the editor shows that it is saving
    And the button {'Create list'} is disabled
    And the button {'Back'} is disabled
    When I swipe back
    Then I am on step {3}
    When I move {'Amber Chronicles #2'} up
    Then the reading order is
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Chronicles #2' |
    When the backend releases {'POST /v1/me/lists'}
    Then the backend received {1} requests for {'POST /v1/me/lists'}
    And the editor completed with list {'l-5'}

  @T-0048-AC6
  Scenario: Going back by the button and by the swipe keeps every step's values
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I enter {'Where Amber begins.'} as the description
    And I tap {'Public'}
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I pick {'Amber Chronicles #2'}
    And I tap {'Next'}
    And I move {'Amber Chronicles #2'} up
    And I swipe back
    Then I am on step {2}
    And the picked comics are
      | 'title'               |
      | 'Amber Chronicles #2' |
      | 'Amber Chronicles #1' |
    When I tap {'Back'}
    Then I am on step {1}
    And the name field shows {'Amber reads'}
    And the description field shows {'Where Amber begins.'}
    And the visibility is {'Public'}
    When I tap {'Next'}
    And I tap {'Next'}
    Then the reading order is
      | 'title'               |
      | 'Amber Chronicles #2' |
      | 'Amber Chronicles #1' |
    When I tap {'Create list'}
    Then the backend received {'POST /v1/me/lists'} with the body
      | 'key'         | 'json'                  |
      | 'name'        | '"Amber reads"'         |
      | 'description' | '"Where Amber begins."' |
      | 'visibility'  | '"public"'              |
      | 'comicIds'    | '[500061, 500060]'      |
    And the editor completed with list {'l-5'}

  @T-0048-AC6
  Scenario: Going back while a search is held, its late answer changes nothing
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    Given the backend holds {'GET /v1/comics?titleStartsWith=Amber Fr'}
    When I search for {'Amber Fr'}
    And the app sends {'GET /v1/comics?titleStartsWith=Amber Fr'}
    And I tap {'Back'}
    Then I am on step {1}
    When the backend releases {'GET /v1/comics?titleStartsWith=Amber Fr'}
    And I tap {'Next'}
    Then I am on step {2}
    And the picked comics are
      | 'title'               |
      | 'Amber Chronicles #1' |
    And I see {'Amber Chronicles #2'}
    And I don't see {'Amber Frontier #1'}

  @T-0048-AC6
  Scenario: Another user signing in during the save gets nothing written, and the list is not handed out
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    Given the backend holds {'POST /v1/me/lists'}
    When I tap {'Create list'}
    And the app sends {'POST /v1/me/lists'}
    And {'collector@mini-client.test'} signs in elsewhere
    And the backend releases {'POST /v1/me/lists'}
    Then I see {'You are no longer signed in as before'}
    And the editor has not ended
    And the backend received {1} requests for {'POST /v1/me/lists'}
    And the backend received {'POST /v1/me/lists'} with a token of {'reader@mini-client.test'}
    And {'collector@mini-client.test'} has {1} reading lists
    And the app announced {0} change to {'readingLists'}
    When I tap {'Close'}
    Then the editor ended without a list

  @T-0048-AC6
  Scenario: A sign-out during the save writes nothing more and hands out no list
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    Given the backend holds {'POST /v1/me/lists'}
    When I tap {'Create list'}
    And the app sends {'POST /v1/me/lists'}
    And the session ends elsewhere
    And the backend releases {'POST /v1/me/lists'}
    Then I see {'You are no longer signed in as before'}
    And the editor is back on its first page
    And the editor has not ended
    When I tap {'Close'}
    Then the editor ended without a list

  @T-0048-AC6
  Scenario: A sign-out before Finish ends the editing and sends nothing
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    And the session ends elsewhere
    Then I see {'You are no longer signed in as before'}
    And I don't see {'Create list'}
    And the backend received {0} requests for {'POST /v1/me/lists'}

  @T-0048-AC6
  Scenario: Another user signing in between the two writes of an edit stops the second
    When I open the reading list editor for {'l-1'}
    And I enter {'Spider-Verse Basics'} as the name
    And I tap {'Next'}
    And I tap {'Next'}
    And I move {'Amber Legacy #1'} up
    Given the backend holds {'PUT /v1/me/lists/l-1'}
    When I tap {'Save changes'}
    And the app sends {'PUT /v1/me/lists/l-1'}
    And {'collector@mini-client.test'} signs in elsewhere
    And the backend releases {'PUT /v1/me/lists/l-1'}
    Then the backend received {1} requests for {'PUT /v1/me/lists/l-1'}
    And the backend received {'PUT /v1/me/lists/l-1'} with a token of {'reader@mini-client.test'}
    And the backend received {0} requests for {'PUT /v1/me/lists/:id/items'}
    And I see {'You are no longer signed in as before'}
    And list {'l-1'} of {'reader@mini-client.test'} holds the comics
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Frontier #1'   |
      | 'Amber Legacy #1'     |

  @T-0048-AC6
  Scenario: A session change while the list loads shows no list of the old session
    Given the backend holds {'GET /v1/me/lists/l-1'}
    When I open the reading list editor for {'l-1'}
    And the app sends {'GET /v1/me/lists/l-1'}
    And {'collector@mini-client.test'} signs in elsewhere
    And the backend releases {'GET /v1/me/lists/l-1'}
    Then I see {'You are no longer signed in as before'}
    And I don't see {'Spider-Verse Starter'}
    And I don't see {'Step 1 of 3'}

  @T-0048-AC6
  Scenario: A slow search that answers after a newer one changes nothing
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    Given the backend holds {'GET /v1/comics?titleStartsWith=Amber Ch'}
    When I search for {'Amber Ch'}
    And the app sends {'GET /v1/comics?titleStartsWith=Amber Ch'}
    And I search for {'Amber Fr'}
    Then I see {'Amber Frontier #1'}
    When the backend releases {'GET /v1/comics?titleStartsWith=Amber Ch'}
    Then I see {'Amber Frontier #1'}
    And I don't see {'Amber Chronicles #3'}
