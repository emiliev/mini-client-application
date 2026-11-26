Feature: Edit a reading list
  A reader opens one of their lists in the same three steps, finds every
  step filled in, and saves only what they changed.

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'identity.default'}
    And the backend serves {'library.default'}
    And I am signed in as {'reader@mini-client.test'}

  @T-0048-AC3 @smoke
  Scenario: Editing loads the list and fills in every step
    When I open the reading list editor for {'l-1'}
    Then I see {'Edit reading list'}
    And the name field shows {'Spider-Verse Starter'}
    And the description field shows {'Where to begin.'}
    And the visibility is {'Public'}
    And the backend received {1} requests for {'GET /v1/me/lists/l-1'}
    When I tap {'Next'}
    Then the picked comics are
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Frontier #1'   |
      | 'Amber Legacy #1'     |
    When I tap {'Next'}
    Then the reading order is
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Frontier #1'   |
      | 'Amber Legacy #1'     |
    And I see {'Save changes'}

  @T-0048-AC3
  Scenario: Saving without a change sends nothing and completes with the same id
    When I open the reading list editor for {'l-1'}
    And I tap {'Next'}
    And I tap {'Next'}
    And I tap {'Save changes'}
    Then the backend received {0} requests for {'PUT /v1/me/lists/:id'}
    And the backend received {0} requests for {'PUT /v1/me/lists/:id/items'}
    And the editor completed with list {'l-1'}
    And the app announced {0} change to {'readingLists'}

  @T-0048-AC3
  Scenario: A new name sends only the details
    When I open the reading list editor for {'l-1'}
    And I enter {'Spider-Verse Basics'} as the name
    And I tap {'Next'}
    And I tap {'Next'}
    And I tap {'Save changes'}
    Then the backend received {1} requests for {'PUT /v1/me/lists/l-1'}
    And the backend received {'PUT /v1/me/lists/l-1'} with the body
      | 'key'         | 'json'                  |
      | 'name'        | '"Spider-Verse Basics"' |
      | 'description' | '"Where to begin."'     |
      | 'visibility'  | '"public"'              |
    And the backend received {0} requests for {'PUT /v1/me/lists/:id/items'}
    And the editor completed with list {'l-1'}
    And list {'l-1'} of {'reader@mini-client.test'} is named {'Spider-Verse Basics'}
    And the app announced {1} change to {'readingLists'}

  @T-0048-AC3
  Scenario: A new order sends only the items
    When I open the reading list editor for {'l-1'}
    And I tap {'Next'}
    And I tap {'Next'}
    And I move {'Amber Legacy #1'} up
    And I tap {'Save changes'}
    Then the backend received {0} requests for {'PUT /v1/me/lists/:id'}
    And the backend received {1} requests for {'PUT /v1/me/lists/l-1/items'}
    And the backend received {'PUT /v1/me/lists/l-1/items'} with the body
      | 'key'      | 'json'                     |
      | 'comicIds' | '[500060, 500540, 501500]' |
    And the editor completed with list {'l-1'}
    And list {'l-1'} of {'reader@mini-client.test'} holds the comics
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Legacy #1'     |
      | 'Amber Frontier #1'   |

  @T-0048-AC3
  Scenario: Details and comics that both changed are both sent, the details first
    When I open the reading list editor for {'l-1'}
    And I tap {'Private'}
    And I tap {'Next'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Next'}
    And I tap {'Save changes'}
    Then the backend received {1} requests for {'PUT /v1/me/lists/l-1'}
    And the backend received {1} requests for {'PUT /v1/me/lists/l-1/items'}
    And the backend received {'PUT /v1/me/lists/l-1/items'} with the body
      | 'key'      | 'json'             |
      | 'comicIds' | '[501500, 500540]' |
    And the requests to the list went in the order
      | 'route'                      |
      | 'GET /v1/me/lists/l-1'       |
      | 'PUT /v1/me/lists/l-1'       |
      | 'PUT /v1/me/lists/l-1/items' |
    And the editor completed with list {'l-1'}
    And the app announced {1} change to {'readingLists'}

  @T-0048-AC3 @T-0048-AC2
  Scenario: When the details saved and the comics failed, Retry sends only the comics
    Given the backend fails {'PUT /v1/me/lists/l-1/items'} with {'server_error'}
    When I open the reading list editor for {'l-1'}
    And I enter {'Spider-Verse Basics'} as the name
    And I tap {'Next'}
    And I tap {'Next'}
    And I move {'Amber Legacy #1'} up
    And I tap {'Save changes'}
    Then the save error reads {'The server had a problem. Please try again later.'}
    And the backend received {1} requests for {'PUT /v1/me/lists/l-1'}
    And the editor has not ended
    When the backend recovers
    And I tap {'Retry'}
    Then the backend received {1} requests for {'PUT /v1/me/lists/l-1'}
    And the editor completed with list {'l-1'}
    And list {'l-1'} of {'reader@mini-client.test'} is named {'Spider-Verse Basics'}
    And list {'l-1'} of {'reader@mini-client.test'} holds the comics
      | 'title'               |
      | 'Amber Chronicles #1' |
      | 'Amber Legacy #1'     |
      | 'Amber Frontier #1'   |

  @T-0048-AC3
  Scenario Outline: A list that is not the reader's shows that it was not found
    When I open the reading list editor for <list>
    Then I see {'List not found'}
    And I see {'This reading list does not exist or is not yours.'}
    And I don't see {'Step 1 of 3'}
    And I don't see {'Retry'}
    And the backend received {0} requests for {'PUT /v1/me/lists/:id'}
    And the editor has not ended

    Examples:
      | list    |
      | 'l-4'   |
      | 'l-999' |

  @T-0048-AC3 @T-0048-AC2
  Scenario: A list that fails to load explains the problem, and Retry recovers
    Given the backend fails {'GET /v1/me/lists/l-1'} with {'offline'}
    When I open the reading list editor for {'l-1'}
    Then I see {'The reading list could not be loaded'}
    And I see {'No connection. Check your network and try again.'}
    When the backend recovers
    And I tap {'Retry'}
    Then the name field shows {'Spider-Verse Starter'}

  @T-0048-AC1
  Scenario: A list holds at most 100 comics
    Given {'reader@mini-client.test'} has a list of {100} comics
    When I open the reading list editor for {'l-5'}
    And I tap {'Next'}
    And I search for {'Amber Fr'}
    And I pick {'Amber Frontier #1'}
    Then the comics error reads {'Pick at most 100 comics.'}
    And the button {'Next'} is disabled
    When I pick {'Amber Frontier #1'}
    Then I see {'100 comics picked'}
    And I don't see {'Pick at most 100 comics.'}
