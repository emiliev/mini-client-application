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
