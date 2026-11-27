Feature: Sign in
  A reader signs in with an email and a password. The form ends with a
  result that says whether anyone is signed in, and tells wrong credentials
  from a backend that is down.

  Background:
    Given the backend serves {'identity.default'}

  @T-0066-AC1 @smoke
  Scenario: A fixture user's credentials sign them in
    When I open the sign-in form
    Then I see {'Use your Mini Client account.'}
    And nobody is signed in
    When I enter {'reader@mini-client.test'} in the field {'Email'}
    And I enter {'marvelous'} in the field {'Password'}
    And I submit the form
    Then the backend received {1} requests for {'POST /v1/auth/sign-in'}
    And the backend received {'POST /v1/auth/sign-in'} with the body
      | 'key'      | 'json'                      |
      | 'email'    | '"reader@mini-client.test"' |
      | 'password' | '"marvelous"'               |
    And the backend answered {'POST /v1/auth/sign-in'} with {200}
    And the session belongs to {'reader@mini-client.test'}
    And the sign-in completed with {'signedIn'}

  @T-0066-AC1
  Scenario: The email is sent trimmed and matches in any case
    When I open the sign-in form
    And I enter {'  COLLECTOR@mini-client.test '} in the field {'Email'}
    And I enter {'vault-7'} in the field {'Password'}
    And I submit the form
    Then the backend received {'POST /v1/auth/sign-in'} with the body
      | 'key'      | 'json'                         |
      | 'email'    | '"COLLECTOR@mini-client.test"' |
      | 'password' | '"vault-7"'                    |
    And the session belongs to {'collector@mini-client.test'}
    And the sign-in completed with {'signedIn'}

  @T-0066-AC1
  Scenario Outline: Wrong credentials show a typed error on the form and sign nobody in
    When I open the sign-in form
    And I enter {<email>} in the field {'Email'}
    And I enter {<password>} in the field {'Password'}
    And I submit the form
    Then the backend answered {'POST /v1/auth/sign-in'} with {401}
    And I see {'The email or password is wrong.'}
    And the submit button reads {'Sign in'}
    And nobody is signed in
    And the sign-in has not completed
    And the field {'Email'} holds {<email>}

    Examples:
      | email                       | password     |
      | 'reader@mini-client.test'   | 'not-it'     |
      | 'stranger@mini-client.test' | 'marvelous'  |

  @T-0066-AC1
  Scenario: After wrong credentials, correcting the password signs in
    When I open the sign-in form
    And I enter {'reader@mini-client.test'} in the field {'Email'}
    And I enter {'not-it'} in the field {'Password'}
    And I submit the form
    Then I see {'The email or password is wrong.'}
    When I enter {'marvelous'} in the field {'Password'}
    Then I don't see {'The email or password is wrong.'}
    When I submit the form
    Then the session belongs to {'reader@mini-client.test'}
    And the sign-in completed with {'signedIn'}

  @T-0066-AC1
  Scenario: A server error shows an error with a retry, and the retry signs in
    Given the backend fails {'POST /v1/auth/sign-in'} with {'server_error'}
    When I open the sign-in form
    And I enter {'reader@mini-client.test'} in the field {'Email'}
    And I enter {'marvelous'} in the field {'Password'}
    And I submit the form
    Then I see {'Could not sign in. The server had a problem. Please try again later.'}
    And the submit button reads {'Try again'}
    And nobody is signed in
    And the sign-in has not completed
    When the backend recovers
    And I submit the form
    Then the session belongs to {'reader@mini-client.test'}
    And the sign-in completed with {'signedIn'}

  @T-0066-AC1
  Scenario: With the identity service down (the scenario), the form says so and signs nobody in
    Given the backend runs the scenario {'identity.server_error'}
    When I open the sign-in form
    And I enter {'reader@mini-client.test'} in the field {'Email'}
    And I enter {'marvelous'} in the field {'Password'}
    And I submit the form
    Then the backend answered {'POST /v1/auth/sign-in'} with {500}
    And I see {'Could not sign in. The server had a problem. Please try again later.'}
    And the submit button reads {'Try again'}
    And nobody is signed in

  @T-0066-AC1
  Scenario: A sign-in that hands out an expired access token is a normal sign-in, refreshed on first use
    Given the backend runs the scenario {'identity.expired_token'}
    When I open the sign-in form
    And I enter {'reader@mini-client.test'} in the field {'Email'}
    And I enter {'marvelous'} in the field {'Password'}
    And I submit the form
    Then the session belongs to {'reader@mini-client.test'}
    And the sign-in completed with {'signedIn'}
    When the app asks who is signed in and is answered {200}
    Then the backend received {1} requests for {'POST /v1/auth/refresh'}
    And the session belongs to {'reader@mini-client.test'}

  @T-0066-AC1
  Scenario: A double tap on Submit sends exactly one request
    Given the backend holds {'POST /v1/auth/sign-in'}
    When I open the sign-in form
    And I enter {'reader@mini-client.test'} in the field {'Email'}
    And I enter {'marvelous'} in the field {'Password'}
    And I submit the form twice in quick succession
    Then the button {'Signing in'} is disabled
    And the button {'Not now'} is disabled
    When I let the sign-in request through
    Then the backend received {1} requests for {'POST /v1/auth/sign-in'}
    And the sign-in completed with {'signedIn'}
    And the session belongs to {'reader@mini-client.test'}

  @T-0066-AC1
  Scenario: Submitting an empty form asks for both fields and sends nothing
    When I open the sign-in form
    And I submit the form
    Then the error {'Enter your email address.'} shows under the field {'Email'}
    And the error {'Enter your password.'} shows under the field {'Password'}
    And the backend received {0} requests for {'POST /v1/auth/sign-in'}
    And the sign-in has not completed

  @T-0066-AC1
  Scenario: Something that is not an email address is refused before any request
    When I open the sign-in form
    And I enter {'reader'} in the field {'Email'}
    And I enter {'marvelous'} in the field {'Password'}
    And I submit the form
    Then the error {'Enter a valid email address.'} shows under the field {'Email'}
    And the backend received {0} requests for {'POST /v1/auth/sign-in'}

  @T-0066-AC1
  Scenario: A demo account fills the form and signs in
    When I open the sign-in form with the demo accounts
    Then I see the texts
      | 'text'                                           |
      | 'Use a demo account'                             |
      | 'Fills in the form with a test account.'         |
      | 'Rhea Reader (reader@mini-client.test)'          |
      | 'Cole Collector (collector@mini-client.test)'    |
    When I tap {'Cole Collector (collector@mini-client.test)'}
    Then the field {'Email'} holds {'collector@mini-client.test'}
    And the field {'Password'} holds {'vault-7'}
    And nobody is signed in
    When I submit the form
    Then the session belongs to {'collector@mini-client.test'}
    And the sign-in completed with {'signedIn'}

  @T-0066-AC1
  Scenario: Without demo accounts the helper is not offered
    When I open the sign-in form
    Then I don't see {'Use a demo account'}

  @T-0066-AC1
  Scenario: Not now completes as cancelled and signs nobody in
    When I open the sign-in form
    And I tap {'Not now'}
    Then the sign-in completed with {'cancelled'}
    And nobody is signed in
    And the backend received {0} requests for {'POST /v1/auth/sign-in'}

  @T-0066-AC1
  Scenario Outline: The screen says what the sign-in is for
    When I open the sign-in form for {<code>}
    Then I see {<line>}

    Examples:
      | code               | line                                                  |
      | 'favourites'       | 'Sign in to keep your favourites.'                    |
      | 'readingLists'     | 'Sign in to save your reading lists.'                 |
      | 'cart'             | 'Sign in to use your cart.'                           |
      | 'triviaResults'    | 'Sign in to keep your trivia results.'                |
      | 'appearanceSync'   | 'Sign in to sync your appearance across devices.'     |
      | 'a hostile phrase' | 'Use your Mini Client account.'                       |
