Feature: Favourite a comic
  Fans keep comics among their favourites. Signed out, the app asks them to
  sign in first; signed in, the toggle answers at once and owns up when the
  write fails.

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'characters.default'}
    And the backend serves {'identity.default'}

  @T-0041-AC6 @smoke
  Scenario: Signed out, the favourite waits for sign-in and then saves it
    When I open comic {501500}
    And I tap {'Add to favourites'}
    Then the app was asked to sign in {1} time
    And the backend received {0} requests for {'* /v1/me/favourites/:kind/:id'}
    And the app announced {0} change to {'favourites'}
    When signing in succeeds as {'reader@mini-client.test'}
    Then I see {'Remove from favourites'}
    And the backend received {1} requests for {'PUT /v1/me/favourites/comic/501500'}
    And the app sent {'PUT /v1/me/favourites/comic/501500'} with the bearer of {'reader@mini-client.test'}
    And the backend answered {'PUT /v1/me/favourites/comic/501500'} with {200}
    And comic {501500} is a favourite of {'reader@mini-client.test'}
    And the app announced {1} change to {'favourites'}

  @T-0041-AC6
  Scenario: Signed out, backing out of sign-in changes nothing and sends nothing
    When I open comic {501500}
    And I tap {'Add to favourites'}
    And signing in is cancelled
    Then I see {'Add to favourites'}
    And the app was asked to sign in {1} time
    And the backend received {0} requests for {'* /v1/me/favourites/:kind/:id'}
    And the backend received {0} requests for {'* /v1/me'}
    And the app announced {0} change to {'favourites'}
    And comic {501500} is not a favourite of {'reader@mini-client.test'}

  @T-0041-AC6
  Scenario: Signed out, a double tap asks to sign in once and sends one request
    When I open comic {501500}
    And I tap {'Add to favourites'} twice in quick succession
    Then the app was asked to sign in {1} time
    When signing in succeeds as {'reader@mini-client.test'}
    Then I see {'Remove from favourites'}
    And the backend received {1} requests for {'PUT /v1/me/favourites/comic/501500'}
    And the app announced {1} change to {'favourites'}

  @T-0041-AC6
  Scenario: Signed in, the toggle flips at once and a failed write rolls it back
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    Given the backend holds {'PUT /v1/me/favourites/comic/501500'}
    And the backend fails {'PUT /v1/me/favourites/comic/501500'} with {'server_error'}
    When I tap {'Add to favourites'}
    Then I see {'Remove from favourites'}
    When the backend releases {'PUT /v1/me/favourites/comic/501500'}
    Then I see {'Add to favourites'}
    And I see {'Your favourites could not be updated. Please try again.'}
    And the app was asked to sign in {0} time
    And the app announced {0} change to {'favourites'}
    And comic {501500} is not a favourite of {'reader@mini-client.test'}

  @T-0041-AC6
  Scenario: Signed in, a removal that fails keeps the favourite
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    And I tap {'Add to favourites'}
    Then I see {'Remove from favourites'}
    And the app announced {1} change to {'favourites'}
    Given the backend fails {'DELETE /v1/me/favourites/comic/501500'} with {'offline'}
    When I tap {'Remove from favourites'}
    Then I see {'Remove from favourites'}
    And I see {'Your favourites could not be updated. Please try again.'}
    And the app announced {1} change to {'favourites'}
    And comic {501500} is a favourite of {'reader@mini-client.test'}
    When the backend recovers
    And I tap {'Remove from favourites'}
    Then I see {'Add to favourites'}
    And I don't see {'Your favourites could not be updated. Please try again.'}
    And the app announced {2} change to {'favourites'}
    And comic {501500} is not a favourite of {'reader@mini-client.test'}

  @T-0041-AC6
  Scenario: Signed in, a double tap sends one request
    Given I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    And I tap {'Add to favourites'} twice in quick succession
    Then I see {'Remove from favourites'}
    And the backend received {1} requests for {'PUT /v1/me/favourites/comic/501500'}
    And the backend received {0} requests for {'DELETE /v1/me/favourites/comic/501500'}
    And the app announced {1} change to {'favourites'}

  Scenario: Signed in, the toggle shows a saved favourite
    Given I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has comic {501500} among their favourites
    When I open comic {501500}
    Then I see {'Remove from favourites'}
    And the backend received {1} requests for {'GET /v1/me/favourites/comic/501500'}
    And the app was asked to sign in {0} time

  Scenario: A favourite that cannot be checked says so
    Given I am signed in as {'reader@mini-client.test'}
    And the backend fails {'GET /v1/me/favourites/comic/501500'} with {'server_error'}
    When I open comic {501500}
    Then I see {'Add to favourites'}
    And I see {'Your favourites could not be checked.'}
    When the backend recovers
    And I tap {'Add to favourites'}
    Then I see {'Remove from favourites'}
    And comic {501500} is a favourite of {'reader@mini-client.test'}

  @T-0041-AC4 @l10n
  Scenario: In German the favourite labels and its error are German
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    When I open comic {501500}
    Then I see {'Zu Favoriten hinzufügen'}
    When I tap {'Zu Favoriten hinzufügen'}
    Then I see {'Aus Favoriten entfernen'}
    Given the backend fails {'DELETE /v1/me/favourites/comic/501500'} with {'server_error'}
    When I tap {'Aus Favoriten entfernen'}
    Then I see {'Aus Favoriten entfernen'}
    And I see {'Deine Favoriten konnten nicht aktualisiert werden. Bitte versuche es erneut.'}

  @T-0041-AC4 @l10n
  Scenario: The pseudo-locale renders the favourite error without overflow
    Given the pseudo-locale is active
    And I am signed in as {'reader@mini-client.test'}
    And the backend fails {'PUT /v1/me/favourites/comic/501500'} with {'server_error'}
    When I open comic {501500}
    And I tap {'[Àðð ţó ƒàvóúŕíţéš ~~~~~~~]'}
    Then I see {'[Ýóúŕ ƒàvóúŕíţéš çóúļð ñóţ ƀé úþðàţéð. Þļéàšé ţŕý àĝàíñ. ~~~~~~~~~~~~~~~~~~~~~~]'}
    And nothing overflows
