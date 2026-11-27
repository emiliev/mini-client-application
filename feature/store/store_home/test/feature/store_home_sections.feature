Feature: Independent sections
  Every section of the store home has its own request and its own states. A
  section that fails or is slow never blanks or blocks another, and when two
  loads of one section overlap, the newest request's answer is what shows.

  Background:
    Given the backend serves {'commerce.default'}
    And the backend serves {'identity.default'}
    And I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has {1} of product {500060} in the cart

  @T-0056-AC6
  Scenario Outline: Only the failing section shows an error; the other four render
    Given the backend runs the scenario {<scenario>}
    When I open the store
    Then only the {<section>} section shows an error
    And the section {<section>} was viewed {0} times
    When the backend recovers
    And I tap Retry in the {<section>} section
    Then the {<section>} section is ready
    And the section {<section>} was viewed {1} times

    Examples:
      | scenario                 | section      |
      | 'store.banners_error'    | 'banners'    |
      | 'store.deals_error'      | 'deals'      |
      | 'store.categories_error' | 'categories' |
      | 'store.featured_error'   | 'featured'   |
      | 'store.cart_error'       | 'cart'       |

  @T-0056-AC6
  Scenario: A slow section never blocks the others from rendering
    Given the backend holds {'GET /v1/store/deals'}
    When I open the store
    And the app sends {'GET /v1/store/deals'}
    Then the {'deals'} section is loading
    And the {'banners'} section is ready
    And the {'categories'} section is ready
    And the {'featured'} section is ready
    And the {'cart'} section is ready
    When the backend releases {'GET /v1/store/deals'}
    Then the {'deals'} section is ready
    And the deals section shows every deal with both prices

  @T-0056-AC6
  Scenario: A refresh while a load is in flight ends on the refresh's answer, even when the old one arrives last
    Given the backend holds the next {'GET /v1/store/deals'}
    When I open the store
    And the app sends {'GET /v1/store/deals'}
    Then the {'deals'} section is loading
    When I pull to refresh
    Then the {'deals'} section is ready
    And the backend received {2} requests for {'GET /v1/store/deals'}
    Given the backend fails {'GET /v1/store/deals'} with {'server_error'}
    When the backend releases {'GET /v1/store/deals'}
    Then the {'deals'} section is ready
    And the backend received {4} requests for {'GET /v1/store/deals'}
    And the section {'deals'} was viewed {1} times

  @T-0056-AC6
  Scenario: A failed refresh wins over an older load that succeeds after it
    Given the backend holds the next {'GET /v1/store/deals'}
    When I open the store
    And the app sends {'GET /v1/store/deals'}
    Given the backend fails {'GET /v1/store/deals'} with {'server_error'}
    When I pull to refresh
    Then the {'deals'} section shows its error with Retry
    When the backend recovers
    And the backend releases {'GET /v1/store/deals'}
    Then the {'deals'} section shows its error with Retry
    And the backend received {4} requests for {'GET /v1/store/deals'}
    And the section {'deals'} was viewed {0} times
    When I tap Retry in the {'deals'} section
    Then the {'deals'} section is ready

  @T-0056-AC6
  Scenario: Pull to refresh reloads every section at once and keeps what is shown meanwhile
    When I open the store
    Given the backend holds {'GET /v1/store/banners'}
    And the backend holds {'GET /v1/store/categories'}
    When I pull to refresh
    Then the backend received {2} requests for {'GET /v1/store/banners'}
    And the backend received {2} requests for {'GET /v1/store/deals'}
    And the backend received {2} requests for {'GET /v1/store/categories'}
    And the backend received {2} requests for {'GET /v1/store/featured'}
    And the backend received {2} requests for {'GET /v1/me/cart'}
    And the {'banners'} section is ready
    And the {'categories'} section is ready
    When the backend releases {'GET /v1/store/banners'}
    And the backend releases {'GET /v1/store/categories'}
    Then the {'banners'} section is ready
    And the section {'banners'} was viewed {1} times

  @T-0056-AC7
  Scenario: Each section is viewed once per visit, never when it failed, and after its Retry succeeds
    Given the backend fails {'GET /v1/store/featured'} with {'server_error'}
    When I open the store
    Then the section {'banners'} was viewed {1} times
    And the section {'deals'} was viewed {1} times
    And the section {'categories'} was viewed {1} times
    And the section {'cart'} was viewed {1} times
    And the section {'featured'} was viewed {0} times
    And the analytics event {'store_section_viewed'} was tracked with
      | 'key'     | 'json'      |
      | 'section' | '"deals"'   |
    When I pull to refresh
    Then the section {'deals'} was viewed {1} times
    When the backend recovers
    And I tap Retry in the {'featured'} section
    Then the section {'featured'} was viewed {1} times
    When I tap {'Heroes'} in the {'categories'} section
    And I swipe back
    Then the section {'deals'} was viewed {1} times

  @T-0056-AC7
  Scenario: The screens are tracked in order for store, category and back
    When I open the store
    And I tap {'Heroes'} in the {'categories'} section
    Then the category page of {'heroes'} is open, titled {'Heroes'}
    When I swipe back
    Then the screens tracked are {'store_home, store_category, store_home'}
    And the screen {'store_category'} was tracked

  @T-0056-AC7
  Scenario: A store opened at a category tracks only the category screen
    When I open the store at category {'heroes'}
    Then the category page of {'heroes'} is open, titled {'Heroes'}
    And the screens tracked are {'store_category'}

  @T-0056-AC7
  Scenario Outline: Every kind of tap is tracked with its section, kind and id
    When I open the store
    And I tap {<item>} in the {<section>} section
    Then the store tap was tracked with section {<section>}, kind {<kind>} and id {<id>}

    Examples:
      | item                | section      | kind       | id        |
      | 'New this week'     | 'banners'    | 'comic'    | '500540'  |
      | 'Heroes assemble'   | 'banners'    | 'category' | 'heroes'  |
      | 'Amber season'      | 'banners'    | 'search'   | 'amber'   |
      | 'Amber Frontier #2' | 'deals'      | 'comic'    | '501501'  |
      | 'Cosmic'            | 'categories' | 'category' | 'cosmic'  |
      | 'Amber Crossing #1' | 'featured'   | 'comic'    | '501740'  |
      | 'View cart'         | 'cart'       | 'cart'     | 'summary' |
