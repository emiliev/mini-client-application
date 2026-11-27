Feature: The cart summary follows the session
  Signed out, the store hides the cart summary and offers to sign in; the app
  decides how. Signed in, the summary is that user's cart, and it follows every
  change of session: a load that belongs to a session that is gone never shows.

  Background:
    Given the backend serves {'commerce.default'}
    And the backend serves {'identity.default'}
    And {'reader@mini-client.test'} has {2} of product {500060} in the cart
    And {'collector@mini-client.test'} has {1} of product {500120} in the cart

  @T-0056-AC3 @smoke
  Scenario: Signed out, the cart waits for sign-in and then shows that user's cart
    When I open the store
    And I tap {'Sign in'} in the {'cart'} section
    Then the app was asked to sign in {1} time
    And the {'cart'} section shows {'Waiting for you to sign in.'}
    And the backend received {0} requests for {'GET /v1/me/cart'}
    When signing in succeeds as {'reader@mini-client.test'}
    Then the cart section shows the cart of {'reader@mini-client.test'}
    And the backend received {1} requests for {'GET /v1/me/cart'}
    And the backend received {'GET /v1/me/cart'} with the bearer of {'reader@mini-client.test'}
    And the section {'cart'} was viewed {1} times

  @T-0056-AC3
  Scenario: Signed out, backing out of sign-in keeps the summary hidden and sends nothing
    When I open the store
    And I tap {'Sign in'} in the {'cart'} section
    And signing in is cancelled
    Then the {'cart'} section shows {'Sign in to see your cart.'}
    And the app was asked to sign in {1} time
    And the backend received {0} requests for {'GET /v1/me/cart'}
    And the backend received {0} requests for {'* /v1/me'}

  @T-0056-AC3
  Scenario: Signed out, a double tap asks to sign in once
    When I open the store
    And I tap {'Sign in'} in the {'cart'} section twice in quick succession
    Then the app was asked to sign in {1} time
    When signing in succeeds as {'reader@mini-client.test'}
    Then the cart section shows the cart of {'reader@mini-client.test'}
    And the backend received {1} requests for {'GET /v1/me/cart'}

  @T-0056-AC3
  Scenario: A user switch elsewhere reloads the cart for the new user
    Given I am signed in as {'reader@mini-client.test'}
    When I open the store
    Then the cart section shows the cart of {'reader@mini-client.test'}
    When {'collector@mini-client.test'} signs in elsewhere
    Then the cart section shows the cart of {'collector@mini-client.test'}
    And the backend received {2} requests for {'GET /v1/me/cart'}

  @T-0056-AC3
  Scenario: A user switch while the cart is loading drops the old user's answer
    Given I am signed in as {'reader@mini-client.test'}
    And the backend holds the next {'GET /v1/me/cart'}
    When I open the store
    And the app sends {'GET /v1/me/cart'}
    Then the {'cart'} section is loading
    When {'collector@mini-client.test'} signs in elsewhere
    Then the cart section shows the cart of {'collector@mini-client.test'}
    When the backend releases {'GET /v1/me/cart'}
    Then the cart section shows the cart of {'collector@mini-client.test'}
    And the backend received {2} requests for {'GET /v1/me/cart'}
    And the section {'cart'} was viewed {1} times

  @T-0056-AC3
  Scenario: A sign-out while the cart is loading shows the signed-out offer, not the old cart
    Given I am signed in as {'reader@mini-client.test'}
    And the backend holds {'GET /v1/me/cart'}
    When I open the store
    And the app sends {'GET /v1/me/cart'}
    And the session ends elsewhere
    And the backend releases {'GET /v1/me/cart'}
    Then the {'cart'} section shows {'Sign in to see your cart.'}
    And the section {'cart'} was viewed {0} times
    And the backend received {1} requests for {'GET /v1/me/cart'}

  @T-0056-AC3
  Scenario: A sign-out elsewhere hides the summary again
    Given I am signed in as {'reader@mini-client.test'}
    When I open the store
    Then the cart section shows the cart of {'reader@mini-client.test'}
    When the session ends elsewhere
    Then the {'cart'} section shows {'Sign in to see your cart.'}
    And the backend received {1} requests for {'GET /v1/me/cart'}

  @T-0056-AC3
  Scenario: A sign-in elsewhere while the store waits for its own sign-in loads the cart once
    When I open the store
    And I tap {'Sign in'} in the {'cart'} section
    And {'collector@mini-client.test'} signs in elsewhere
    Then the cart section shows the cart of {'collector@mini-client.test'}
    When signing in is cancelled
    Then the cart section shows the cart of {'collector@mini-client.test'}
    And the backend received {1} requests for {'GET /v1/me/cart'}

  @T-0056-AC3
  Scenario: A failed cart read says so in its own section, and Retry reads it again
    Given I am signed in as {'reader@mini-client.test'}
    And the backend fails {'GET /v1/me/cart'} with {'server_error'}
    When I open the store
    Then the {'cart'} section shows its error with Retry
    And the {'deals'} section is ready
    When the backend recovers
    And I tap Retry in the {'cart'} section
    Then the cart section shows the cart of {'reader@mini-client.test'}

  @T-0056-AC3
  Scenario: Pull to refresh while signed out reloads the store and not the cart
    When I open the store
    And I pull the store to refresh
    Then the backend received {2} requests for {'GET /v1/store/deals'}
    And the backend received {0} requests for {'GET /v1/me/cart'}
    And the {'cart'} section shows {'Sign in to see your cart.'}
