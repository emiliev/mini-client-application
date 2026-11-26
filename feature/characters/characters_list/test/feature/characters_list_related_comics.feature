Feature: A character's comics
  The preview lists the comics the character appears in, and each one leads
  to that comic's page (T-0041, P-068).

  Background:
    Given the backend serves {'characters.default'}

  @T-0041-AC5
  Scenario: The preview lists the comics the character appears in
    Given the backend serves {'comics.default'}
    When I open the characters list
    And I tap {'Amber Alchemist'}
    Then I see {'Comics'}
    And I see the related comics of {'Amber Alchemist'}
    And the backend received {'GET /v1/comics?characterId=100486&limit=5'}

  @T-0041-AC5
  Scenario: A related comic hands over to the app exactly once
    Given the backend serves {'comics.default'}
    When I open the characters list
    And I tap {'Amber Alchemist'}
    And I scroll the preview until I see {'Amber Requiem #8'}
    And I tap {'Amber Requiem #8'}
    Then the app was asked to open comic {'Amber Requiem #8'}

  Scenario: Related comics that fail to load offer Retry, and the preview stays
    Given the backend serves {'comics.default'}
    And the backend fails {'GET /v1/comics'} with {'server_error'}
    When I open the characters list
    And I tap {'Amber Alchemist'}
    Then I see the character preview for {'Amber Alchemist'}
    And I see {'Comics could not be loaded.'}
    When the backend recovers
    And I scroll the preview until I see {'Retry'}
    And I tap {'Retry'}
    Then I see the related comics of {'Amber Alchemist'}

  @T-0041-AC5
  Scenario: A double Retry of the related comics sends one request
    Given the backend serves {'comics.default'}
    And the backend fails {'GET /v1/comics'} with {'malformed'}
    When I open the characters list
    And I tap {'Amber Alchemist'}
    Then I see {'Comics could not be loaded.'}
    When the backend recovers
    And I scroll the preview until I see {'Retry'}
    And I tap {'Retry'} twice in quick succession
    Then I see the related comics of {'Amber Alchemist'}
    And the backend received {2} requests for {'GET /v1/comics'}

  Scenario: A character in no comic says so
    Given the backend serves {'comics.empty'}
    When I open the characters list
    And I tap {'Amber Alchemist'}
    Then I see {'No comics yet.'}
