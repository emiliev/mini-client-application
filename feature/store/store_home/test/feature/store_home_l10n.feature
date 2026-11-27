Feature: The store in German and in the pseudo-locale
  Every string and every price follows the locale. In the pseudo-locale,
  whose strings are longer, nothing overflows at the default text size or at
  twice it.

  Background:
    Given the backend serves {'commerce.default'}
    And the backend serves {'identity.default'}

  @T-0056-AC4 @l10n
  Scenario: In German the sections, the deal prices and the cart are German
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has {2} of product {500060} in the cart
    When I open the store
    Then the sections are {'Highlights, Angebote, Kategorien, Empfohlen, Dein Warenkorb'}
    And I see {'Shop'}
    And the deal of product {501501} reads {'10,83 €'}, {'12,03 €'} struck through and {'Endet in 1 Tag'}
    And the deal of product {502240} reads {'11,89 €'}, {'13,99 €'} struck through and {'Endet in 2 Tagen'}
    And the {'cart'} section shows {'2 Artikel'}
    And the {'cart'} section shows {'Summe 24,24 €'}
    And the {'categories'} section shows {'60 Comics'}

  @T-0056-AC4 @l10n
  Scenario: In German an empty and a failing section are German
    Given the device locale is {'de'}
    And the backend fails {'GET /v1/store/deals'} with {'server_error'}
    When I open the store
    Then the {'deals'} section shows {'Die Angebote konnten nicht geladen werden.'}
    And the {'deals'} section shows {'Erneut versuchen'}
    And the {'cart'} section shows {'Melde dich an, um deinen Warenkorb zu sehen.'}

  @T-0056-AC4 @l10n
  Scenario: In German a loading section is announced in a number-neutral phrase (review round)
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    And the backend holds {'GET /v1/store/deals'}
    And the backend holds {'GET /v1/me/cart'}
    When I open the store
    And the app sends {'GET /v1/me/cart'}
    Then the {'deals'} section is announced as {'Wird geladen: Angebote'}
    And the {'cart'} section is announced as {'Wird geladen: Dein Warenkorb'}
    When the backend releases {'GET /v1/store/deals'}
    And the backend releases {'GET /v1/me/cart'}
    Then the {'deals'} section is ready

  @T-0056-AC4 @l10n
  Scenario: In German the category page is German
    Given the device locale is {'de'}
    When I open the store at category {'nope'}
    Then I see {'Diese Kategorie gibt es im Shop nicht'}
    And I see {'Kategorie'}

  @T-0056-AC4 @l10n
  Scenario: In English the deal prices are formatted from cents
    When I open the store
    Then the deal of product {501501} reads {'€10.83'}, {'€12.03'} struck through and {'Ends in 1 day'}
    And the deal of product {500280} reads {'€5.11'}, {'€10.22'} struck through and {'Ends in 8 days'}

  @T-0056-AC4 @l10n
  Scenario Outline: The pseudo-locale renders the store without overflow
    Given the pseudo-locale is active
    And the text scale is {<scale>}
    And I am signed in as {'reader@mini-client.test'}
    And {'reader@mini-client.test'} has {2} of product {500060} in the cart
    When I open the store
    And I scroll through the whole store
    Then nothing overflows
    And I see {'[Šţóŕé ~~]'}
    When I tap {'Heroes'} in the {'categories'} section
    Then nothing overflows
    When I scroll the category to the end
    Then nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0056-AC4 @l10n
  Scenario Outline: The pseudo-locale renders every section's error and the sign-in offer without overflow
    Given the pseudo-locale is active
    And the text scale is {<scale>}
    And the backend runs the scenario {'commerce.server_error'}
    When I open the store
    And I scroll through the whole store
    Then nothing overflows
    And the {'deals'} section shows its error with Retry

    Examples:
      | scale |
      | 1     |
      | 2     |
