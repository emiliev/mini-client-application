Feature: Create a reading list
  Readers collect comics into reading lists: a name, who can see it, and the
  comics in the order they want to read them. Three steps lead there, and
  the editor hands the new list back to whoever opened it.

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'identity.default'}
    And the backend serves {'library.default'}

  @T-0048-AC1 @smoke
  Scenario: Three steps create a list with the comics in the chosen order
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    Then I see {'New reading list'}
    And I am on step {1}
    When I enter {'Amber reads'} as the name
    And I enter {'Where Amber begins.'} as the description
    And I tap {'Public'}
    And I tap {'Next'}
    Then I am on step {2}
    When I search for {'Amber Chr'}
    And I pick {'Amber Chronicles #1'}
    And I pick {'Amber Chronicles #2'}
    And I pick {'Amber Chronicles #3'}
    Then I see {'3 comics picked'}
    And the picked comics are
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Chronicles #2' |
      | 'Amber Chronicles #3' |
    When I tap {'Next'}
    Then I am on step {3}
    And I see {'Amber reads'}
    And I see {'Where Amber begins.'}
    And the reading order is
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Chronicles #2' |
      | 'Amber Chronicles #3' |
    When I move {'Amber Chronicles #3'} up
    Then the reading order is
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Chronicles #3' |
      | 'Amber Chronicles #2' |
    When I tap {'Create list'}
    Then the backend received {1} requests for {'POST /v1/me/lists'}
    And the backend received {'POST /v1/me/lists'} with the body
      | 'key'         | 'json'                     |
      | 'name'        | '"Amber reads"'            |
      | 'description' | '"Where Amber begins."'    |
      | 'visibility'  | '"public"'                 |
      | 'comicIds'    | '[500060, 500062, 500061]' |
    And the backend received {'POST /v1/me/lists'} with the bearer of {'reader@mini-client.test'}
    And the backend answered {'POST /v1/me/lists'} with {201}
    And the editor completed with list {'l-5'}
    And list {'l-5'} of {'reader@mini-client.test'} is named {'Amber reads'}
    And list {'l-5'} of {'reader@mini-client.test'} holds the comics
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Chronicles #3' |
      | 'Amber Chronicles #2' |
    And the app announced {1} change to {'readingLists'}

  @T-0048-AC1
  Scenario: The name is sent trimmed, a private list is the default, and a picked comic can be dropped again
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter {'  Weekend  '} as the name
    And I tap {'Next'}
    And I search for {'Amber Fr'}
    And I pick {'Amber Frontier #1'}
    And I pick {'Amber Frontier #2'}
    And I tap {'Amber Frontier #1'} in the picked comics
    Then the picked comics are
      | 'title'             |
      | 'Amber Frontier #2' |
    When I pick {'Amber Frontier #2'}
    Then I see {'No comics picked yet'}
    When I pick {'Amber Frontier #3'}
    And I tap {'Next'}
    And I tap {'Create list'}
    Then the backend received {'POST /v1/me/lists'} with the body
      | 'key'         | 'json'      |
      | 'name'        | '"Weekend"' |
      | 'description' | '""'        |
      | 'visibility'  | '"private"' |
      | 'comicIds'    | '[501502]'  |
    And the editor completed with list {'l-5'}

  @T-0048-AC6
  Scenario: An invalid step keeps Next disabled, and a tap on it shows why
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    Then the button {'Next'} is disabled
    And I don't see {'Give your list a name.'}
    When I tap {'Next'}
    Then I am on step {1}
    And the error {'Give your list a name.'} shows under the field {'Name'}
    When I enter {'Amber reads'} as the name
    Then I don't see {'Give your list a name.'}
    When I tap {'Next'}
    Then I am on step {2}
    And the button {'Next'} is disabled
    And I don't see {'Pick at least one comic.'}
    When I tap {'Next'}
    Then I am on step {2}
    And the comics error reads {'Pick at least one comic.'}
    And the backend received {0} requests for {'POST /v1/me/lists'}

  @T-0048-AC1
  Scenario Outline: The details follow the backend's rules
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter <name> as the name
    And I enter <description> as the description
    Then the error <error> shows under the field <field>
    And the button {'Next'} is disabled

    Examples:
      | name                                                            | description                                                                                                                                                                                                                                                                                 | error                           | field                    |
      | '   '                                                           | ''                                                                                                                                                                                                                                                                                          | 'Give your list a name.'        | 'Name'                   |
      | 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' | ''                                                                                                                                                                                                                                                                                          | 'Use at most 60 characters.'    | 'Name'                   |
      | 'Ok'                                                            | 'ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd' | 'Use at most 280 characters.' | 'Description (optional)' |

  @T-0048-AC1
  Scenario: Sixty characters, trimmed, are a valid name
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter {' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa '} as the name
    Then I don't see {'Use at most 60 characters.'}
    When I tap {'Next'}
    Then I am on step {2}

  @T-0048-AC2
  Scenario: A failed save shows an inline error with Retry, and Retry resends once with nothing lost
    Given I am signed in as {'reader@mini-client.test'}
    And the backend fails {'POST /v1/me/lists'} with {'server_error'}
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    And I search for {'Amber Chr'}
    And I pick {'Amber Chronicles #2'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    And I tap {'Create list'}
    Then I am on step {3}
    And the save error reads {'The server had a problem. Please try again later.'}
    And the editor has not ended
    And the backend received {1} requests for {'POST /v1/me/lists'}
    And the reading order is
      | 'title'               |
      | 'Amber Chronicles #2' |
      | 'Amber Chronicles #1' |
    When the backend recovers
    And I tap {'Retry'}
    Then the backend received {2} requests for {'POST /v1/me/lists'}
    And the backend received {'POST /v1/me/lists'} with the body
      | 'key'         | 'json'             |
      | 'name'        | '"Amber reads"'    |
      | 'description' | '""'               |
      | 'visibility'  | '"private"'        |
      | 'comicIds'    | '[500061, 500060]' |
    And the editor completed with list {'l-5'}
    And the app announced {1} change to {'readingLists'}

  @T-0048-AC2
  Scenario: A name the backend refuses takes the wizard back to step 1 with the error under the name
    # The one rule only the backend can check: a reader's list names are
    # unique (case-insensitive, after trimming), and they have "Weekend Reads".
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter {' weekend reads '} as the name
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    And I tap {'Create list'}
    Then the backend answered {'POST /v1/me/lists'} with {400}
    And I am on step {1}
    And the error {'You already have a list with this name. Please choose another.'} shows under the field {'Name'}
    And the button {'Next'} is disabled
    And the editor has not ended
    And the app announced {0} change to {'readingLists'}
    When I enter {' weekend reads '} as the name
    Then the error {'You already have a list with this name. Please choose another.'} shows under the field {'Name'}
    When I enter {'Weekend reads, again'} as the name
    Then I don't see {'You already have a list with this name. Please choose another.'}
    When I tap {'Next'}
    Then the picked comics are
      | 'title'               |
      | 'Amber Chronicles #1' |
    When I tap {'Next'}
    And I tap {'Create list'}
    Then the backend received {2} requests for {'POST /v1/me/lists'}
    And the editor completed with list {'l-5'}

  @T-0048-AC1
  Scenario: Lengths count what a reader sees, on both sides: sixty flags are a valid name
    # A flag is two code points; the form and the backend both count it once.
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter {'🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪🇩🇪'} as the name
    Then I don't see {'Use at most 60 characters.'}
    When I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    And I tap {'Create list'}
    Then the backend answered {'POST /v1/me/lists'} with {201}
    And the editor completed with list {'l-5'}

  @T-0048-AC6
  Scenario: Signed out, the editor asks to sign in first and then opens on step 1
    When I open the reading list editor
    Then the app was asked to sign in {1} time
    And I don't see {'Step 1 of 3'}
    And the backend received {0} requests for {'* /v1/me/lists'}
    When signing in succeeds as {'reader@mini-client.test'}
    Then I see {'New reading list'}
    And I am on step {1}
    And the editor has not ended

  @T-0048-AC6
  Scenario: Signed out, backing out of sign-in closes the editor with no result
    When I open the reading list editor
    And signing in is cancelled
    Then the editor ended without a list
    And the app was asked to sign in {1} time
    And the backend received {0} requests for {'* /v1/me/lists'}
    And the backend received {0} requests for {'* /v1/me/lists/:id'}

  @T-0048-AC1
  Scenario: Search narrows the comics, says when nothing matches, and recovers from a failure
    Given I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter {'Amber reads'} as the name
    And I tap {'Next'}
    Then the backend received {'GET /v1/comics?limit=20'}
    When I search for {'zzz'}
    Then I see {'No comic title starts with “zzz”.'}
    And the backend received {'GET /v1/comics?titleStartsWith=zzz&limit=20'}
    Given the backend fails {'GET /v1/comics'} with {'server_error'}
    When I search for {'Amber'}
    Then I see {'The comics could not be loaded'}
    When the backend recovers
    And I tap {'Retry'}
    Then I see {'Amber Chronicles #1'}
