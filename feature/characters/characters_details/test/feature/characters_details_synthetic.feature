Feature: A character without a bio, an origin or a team
  The synthetic fixture sets have characters with empty text fields; the
  profile leaves those rows out instead of showing empty ones.

  Background:
    Given the backend serves {'characters.paged_45'}
    And the backend serves {'comics.default'}

  @T-0067-AC1
  Scenario: A synthetic character with no bio, origin or team shows no empty rows
    When I open character {100000}
    Then I see {'Hero 01'}
    And I don't see {'Biography'}
    When I scroll the profile until I see {'Details'}
    Then I don't see {'Origin'}
    And I don't see {'Team'}
    And the fact {'First appeared'} reads {'2000'}
