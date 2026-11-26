Feature: Verifier probes at e053e45 (not committed)

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'identity.default'}

  Scenario: Q1 a sign-out between the PUT being queued and sent
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    Given put requests pause before the auth interceptor
    When I tap {'Add to favourites'}
    And the session ends elsewhere
    And the paused request goes on
    And the app finishes writing to storage
    Then I report the backend requests
    And I see {'Add to favourites'}
    And comic {501500} is not a favourite of {'reader@mini-client.test'}

  Scenario: Q2 another user signs in between the PUT being queued and sent
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    Given put requests pause before the auth interceptor
    When I tap {'Add to favourites'}
    And {'collector@mini-client.test'} signs in elsewhere
    And the paused request goes on
    And the app finishes writing to storage
    Then I report the backend requests
    And comic {501500} is not a favourite of {'collector@mini-client.test'}
    And comic {501500} is not a favourite of {'reader@mini-client.test'}
