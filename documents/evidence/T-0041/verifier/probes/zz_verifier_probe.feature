Feature: Verifier probes (not committed)

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'identity.default'}

  Scenario: P1 a sign-out during an in-flight PUT
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    Given the backend holds {'PUT /v1/me/favourites/comic/501500'}
    When I tap {'Add to favourites'}
    And the app sends {'PUT /v1/me/favourites/comic/501500'}
    Then I see {'Remove from favourites'}
    When the session ends elsewhere
    And the backend releases {'PUT /v1/me/favourites/comic/501500'}
    And the app finishes writing to storage
    Then I see {'Add to favourites'}
    And I don't see {'Your favourites could not be updated. Please try again.'}
    And the user is signed out
    And the backend received {1} requests for {'PUT /v1/me/favourites/comic/501500'}
    And comic {501500} is a favourite of {'reader@mini-client.test'}
    And the app announced {1} change to {'favourites'}

  Scenario: P2 a favourite tap during a session refresh
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    Given the backend fails {'PUT /v1/me/favourites/comic/501500'} with {'unauthorized'} once
    And the backend holds {'POST /v1/auth/refresh'}
    When I tap {'Add to favourites'}
    And the app sends {'POST /v1/auth/refresh'}
    And I tap {'Remove from favourites'}
    And I tap {'Remove from favourites'}
    And the backend releases {'POST /v1/auth/refresh'}
    And the app finishes writing to storage
    Then I see {'Remove from favourites'}
    And the backend received {2} requests for {'PUT /v1/me/favourites/comic/501500'}
    And the backend received {0} requests for {'DELETE /v1/me/favourites/comic/501500'}
    And the backend received {1} requests for {'POST /v1/auth/refresh'}
    And the app announced {1} change to {'favourites'}
    And comic {501500} is a favourite of {'reader@mini-client.test'}

  Scenario: P3 a sign-out during the read after sign-in writes nothing
    When I open comic {501500}
    And I tap {'Add to favourites'}
    Given the backend holds {'GET /v1/me/favourites/comic/501500'}
    When signing in succeeds as {'reader@mini-client.test'}
    And the app sends {'GET /v1/me/favourites/comic/501500'}
    And the session ends elsewhere
    And the backend releases {'GET /v1/me/favourites/comic/501500'}
    And the app finishes writing to storage
    Then I see {'Add to favourites'}
    And I don't see {'Your favourites could not be updated. Please try again.'}
    And the app announced {0} change to {'favourites'}
    And the user is signed out
    And the backend answered {'PUT /v1/me/favourites/comic/501500'} with {401}

  Scenario: P4 another user signing in during the read after sign-in gets no write
    When I open comic {501500}
    And I tap {'Add to favourites'}
    Given the backend holds {'GET /v1/me/favourites/comic/501500'}
    When signing in succeeds as {'reader@mini-client.test'}
    And the app sends {'GET /v1/me/favourites/comic/501500'}
    And {'collector@mini-client.test'} signs in elsewhere
    And the backend releases {'GET /v1/me/favourites/comic/501500'}
    And the app finishes writing to storage
    Then the backend received {'PUT /v1/me/favourites/comic/501500'} with the bearer of {'collector@mini-client.test'}
    And comic {501500} is a favourite of {'collector@mini-client.test'}
    And comic {501500} is not a favourite of {'reader@mini-client.test'}
    And the app announced {1} change to {'favourites'}
    And I see {'Remove from favourites'}

  Scenario: P5 a switch to another user elsewhere shows that user's flag
    Given I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has comic {501500} among their favourites
    When I open comic {501500}
    Then I see {'Remove from favourites'}
    When {'collector@mini-client.test'} signs in elsewhere
    Then I see {'Add to favourites'}
    When I tap {'Add to favourites'}
    Then I see {'Remove from favourites'}
    And comic {501500} is a favourite of {'collector@mini-client.test'}
    And the backend received {0} requests for {'DELETE /v1/me/favourites/comic/501500'}
