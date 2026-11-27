Feature: The store front
  The store home shows its sections one under the other: highlights, deals,
  categories, featured comics and the cart. Each loads, fails and retries on
  its own. A category opens its products inside the store; a comic, a search
  and the cart are other features.

  Background:
    Given the backend serves {'commerce.default'}
    And the backend serves {'identity.default'}

  @T-0056-AC1 @smoke
  Scenario: Signed in, the five sections show the store in order
    Given I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has {2} of product {500060} in the cart
    And {'reader@mini-client.test'} has {1} of product {500120} in the cart
    When I open the store
    Then the sections are {'Highlights, Deals, Categories, Featured, Your cart'}
    And the banners section shows every banner of the store
    And the deals section shows every deal with both prices
    And the categories section shows every category of the store
    And the featured section shows every featured comic with its price
    And the cart section shows the cart of {'reader@mini-client.test'}
    And the backend received {1} requests for {'GET /v1/store/banners'}
    And the backend received {1} requests for {'GET /v1/store/deals'}
    And the backend received {1} requests for {'GET /v1/store/categories'}
    And the backend received {1} requests for {'GET /v1/store/featured'}
    And the backend received {1} requests for {'GET /v1/me/cart'}
    And the backend received {'GET /v1/me/cart'} with the bearer of {'reader@mini-client.test'}

  @T-0056-AC1
  Scenario: Signed out, the cart summary is hidden and nothing asks for it
    When I open the store
    Then the sections are {'Highlights, Deals, Categories, Featured, Your cart'}
    And the {'cart'} section shows {'Sign in to see your cart.'}
    And the backend received {0} requests for {'GET /v1/me/cart'}
    And the app was asked to sign in {0} time

  @T-0056-AC1 @T-0056-AC7
  Scenario: With the featured flag off, the featured section is absent and never requested
    Given the flag {'store.home_featured'} is {false}
    When I open the store
    Then the sections are {'Highlights, Deals, Categories, Your cart'}
    And the backend received {0} requests for {'GET /v1/store/featured'}
    And the backend received {1} requests for {'GET /v1/store/deals'}
    And the section {'featured'} was viewed {0} times
    And the section {'deals'} was viewed {1} times

  @T-0056-AC1 @T-0056-AC7
  Scenario: With the featured flag on, the featured section is there (control)
    Given the flag {'store.home_featured'} is {true}
    When I open the store
    Then the sections are {'Highlights, Deals, Categories, Featured, Your cart'}
    And the featured section shows every featured comic with its price
    And the backend received {1} requests for {'GET /v1/store/featured'}

  @T-0056-AC1
  Scenario: A flag value of the wrong type is the default: featured shows
    Given the flag {'store.home_featured'} is {'off'}
    When I open the store
    Then the sections are {'Highlights, Deals, Categories, Featured, Your cart'}

  @T-0056-AC2
  Scenario: When every store route fails, each section shows its own error and each Retry recovers only its own section
    Given I am signed in as {'reader@mini-client.test'}
    And the backend runs the scenario {'commerce.server_error'}
    When I open the store
    Then the {'banners'} section shows its error with Retry
    And the {'deals'} section shows its error with Retry
    And the {'categories'} section shows its error with Retry
    And the {'featured'} section shows its error with Retry
    And the {'cart'} section shows its error with Retry
    When the backend recovers
    And I tap Retry in the {'deals'} section
    Then the {'deals'} section is ready
    And the {'banners'} section shows its error with Retry
    And the {'categories'} section shows its error with Retry
    And the {'featured'} section shows its error with Retry
    And the {'cart'} section shows its error with Retry
    And the backend received {3} requests for {'GET /v1/store/banners'}
    And the backend received {4} requests for {'GET /v1/store/deals'}
    When I tap Retry in the {'banners'} section
    Then the {'banners'} section is ready
    And the {'categories'} section shows its error with Retry
    When I tap Retry in the {'categories'} section
    And I tap Retry in the {'featured'} section
    And I tap Retry in the {'cart'} section
    Then the {'categories'} section is ready
    And the {'featured'} section is ready
    And the {'cart'} section shows {'Your cart is empty.'}
    And the backend received {4} requests for {'GET /v1/store/banners'}
    And the backend received {4} requests for {'GET /v1/store/deals'}
    And the backend received {4} requests for {'GET /v1/me/cart'}

  @T-0056-AC2
  Scenario: A double tap on Retry loads the section once
    Given the backend fails {'GET /v1/store/deals'} with {'server_error'}
    When I open the store
    Then the {'deals'} section shows its error with Retry
    When the backend recovers
    And I tap Retry in the {'deals'} section twice in quick succession
    Then the {'deals'} section is ready
    And the backend received {4} requests for {'GET /v1/store/deals'}

  @T-0056-AC2
  Scenario: An empty store shows each section's empty state
    Given the backend runs the scenario {'commerce.empty'}
    And I am signed in as {'reader@mini-client.test'}
    When I open the store
    Then the {'banners'} section shows {'No highlights right now.'}
    And the {'deals'} section shows {'No deals right now.'}
    And the {'categories'} section shows {'No categories yet.'}
    And the {'featured'} section shows {'Nothing is featured right now.'}
    And the {'cart'} section shows {'Your cart is empty.'}
    And no analytics event was tracked

  @T-0056-AC3
  Scenario: A deal opens its comic, once
    When I open the store
    And I tap {'Amber Frontier #2'} in the {'deals'} section
    Then the app was asked to open comic {501501} {1} times
    And the analytics event {'store_item_tapped'} was tracked with
      | 'key'     | 'json'      |
      | 'section' | '"deals"' |
      | 'kind'    | '"comic"' |
      | 'id'      | '"501501"' |

  @T-0056-AC3
  Scenario: A second tap on a deal within 500 ms is ignored; one after it opens the comic again
    When I open the store
    And I tap {'Amber Frontier #2'} in the {'deals'} section twice in quick succession
    Then the app was asked to open comic {501501} {1} times
    When I tap {'Amber Frontier #2'} in the {'deals'} section and again after {499} milliseconds
    Then the app was asked to open comic {501501} {2} times
    When I tap {'Amber Frontier #2'} in the {'deals'} section and again after {500} milliseconds
    Then the app was asked to open comic {501501} {4} times

  @T-0056-AC3
  Scenario: A featured comic opens its comic, once
    When I open the store
    And I tap {'Amber Crossing #1'} in the {'featured'} section
    Then the app was asked to open comic {501740} {1} times

  @T-0056-AC3
  Scenario: A comic banner opens its comic, a search banner the search
    When I open the store
    And I tap {'New this week'} in the {'banners'} section
    Then the app was asked to open comic {500540} {1} times
    When I tap {'Amber season'} in the {'banners'} section
    Then the app was asked to search for {'amber'}
    And the app was asked to open the cart {0} times

  @T-0056-AC3
  Scenario: A category banner opens the category inside the store and names it
    When I open the store
    And I tap {'Heroes assemble'} in the {'banners'} section
    Then the category page of {'heroes'} is open, titled {'Heroes'}
    And the category page shows the first {20} products of {'heroes'}
    And the app was asked to open no comic

  @T-0056-AC3
  Scenario: A category opens inside the store, and the next page loads at the end of the list
    When I open the store
    And I tap {'Cosmic'} in the {'categories'} section
    Then the category page of {'cosmic'} is open, titled {'Cosmic'}
    And the category page shows the first {20} products of {'cosmic'}
    And the backend received {0} requests for {'GET /v1/store/categories/cosmic/products?offset=20'}
    When I scroll the category to the end
    Then the backend received {1} requests for {'GET /v1/store/categories/cosmic/products?offset=20&limit=20'}
    And the category page shows the first {40} products of {'cosmic'}
    When I tap {'Gale Chronicles #1'} on the category page
    Then the app was asked to open comic {500160} {1} times

  @T-0056-AC3
  Scenario: Back from the category returns to the store, which keeps its sections
    When I open the store
    And I tap {'Heroes'} in the {'categories'} section
    Then the category page of {'heroes'} is open, titled {'Heroes'}
    When I swipe back
    Then the {'categories'} section is ready
    And the backend received {1} requests for {'GET /v1/store/categories'}
    And the backend received {1} requests for {'GET /v1/store/deals'}

  @T-0056-AC3
  Scenario: The cart summary opens the cart
    Given I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has {1} of product {500060} in the cart
    When I open the store
    And I tap {'View cart'} in the {'cart'} section
    Then the app was asked to open the cart {1} times
