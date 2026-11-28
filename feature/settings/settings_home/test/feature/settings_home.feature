Feature: Settings
  The settings index shows who is signed in, with Sign in or Sign out, the
  Appearance row with the current theme, and About: the app's build and the
  mocked backend's seed. It follows the session, and what it learned of one
  user never shows for another.

  Background:
    Given the backend serves {'identity.default'}

  @T-0070-AC1 @smoke
  Scenario: Signed out, the index shows Not signed in with Sign in, Appearance with its theme, and About
    When I open the settings
    Then I see {'Settings'}
    And I see {'Not signed in'}
    And I see {'Sign in'}
    And I don't see {'Sign out'}
    And I see {'Appearance'}
    And the row {'appearance'} reads {'System'}
    And I see {'Build'}
    And the row {'about.version'} reads {'test'}
    And I see {'Mocked backend seed'}
    And the row {'about.seed'} reads {'42'}
    And the backend received {0} requests for {'GET /v1/me'}
    And the screens tracked are {'settings_home'}

  @T-0070-AC1 @smoke
  Scenario: Signed in as the collector, the index shows the user and Sign out
    Given I am signed in as {'collector@mini-client.test'}
    When I open the settings
    Then I see {'Signed in as Cole Collector'}
    And the row {'account'} reads {'collector@mini-client.test'}
    And I see {'Sign out'}
    And I don't see {'Sign in'}
    And I don't see {'Not signed in'}
    And the backend received {1} requests for {'GET /v1/me'}

  @T-0070-AC1
  Scenario: The profile cannot be read: the user is named by id, and the page still works
    Given I am signed in as {'collector@mini-client.test'}
    And the backend fails {'GET /v1/me'} with {'server_error'}
    When I open the settings
    Then I see {'Signed in as u-101'}
    And I see {'Sign out'}
    And I see {'Appearance'}
    And no error was reported
    When the backend recovers
    And {'reader@mini-client.test'} signs in elsewhere
    Then I see {'Signed in as Rhea Reader'}

  @T-0070-AC1
  Scenario: The Appearance row shows the theme chosen elsewhere, also after a sign-out
    When I open the settings
    And the theme mode is changed elsewhere to {'dark'}
    Then the row {'appearance'} reads {'Dark'}
    When the theme mode is changed elsewhere to {'light'}
    Then the row {'appearance'} reads {'Light'}
    When the theme mode is changed elsewhere to {'system'}
    Then the row {'appearance'} reads {'System'}

  @T-0070-AC2 @smoke
  Scenario: Sign in waits for the app, then the index shows the user
    When I open the settings
    And I tap {'Sign in'}
    Then the app was asked to sign in {1} time
    When signing in succeeds as {'collector@mini-client.test'}
    Then I see {'Signed in as Cole Collector'}
    And I see {'Sign out'}
    And I don't see {'Not signed in'}
    And the backend received {1} requests for {'GET /v1/me'}

  @T-0070-AC2
  Scenario: Backing out of sign-in leaves the index signed out, and Sign in can be tapped again
    When I open the settings
    And I tap {'Sign in'}
    And signing in is cancelled
    Then I see {'Not signed in'}
    And I see {'Sign in'}
    And the app was asked to sign in {1} time
    And the backend received {0} requests for {'GET /v1/me'}
    When I tap {'Sign in'}
    Then the app was asked to sign in {2} times

  @T-0070-AC2
  Scenario: A sign-in that breaks is reported, and Sign in can be tapped again
    When I open the settings
    And I tap {'Sign in'}
    And signing in fails
    Then I see {'Not signed in'}
    And {1} errors were reported
    When I tap {'Sign in'}
    Then the app was asked to sign in {2} times

  @T-0070-AC2
  Scenario: A double tap on Sign in asks the app once
    When I open the settings
    And I tap {'Sign in'} twice in quick succession
    Then the app was asked to sign in {1} time
    When signing in is cancelled
    Then I see {'Sign in'}

  @T-0070-AC2 @smoke
  Scenario: Sign out ends the session, and the index shows Not signed in
    Given I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And I tap {'Sign out'}
    Then the app was asked to sign out {1} time
    When the app signs the user out
    Then I see {'Not signed in'}
    And I see {'Sign in'}
    And I don't see {'Signed in as Cole Collector'}
    And I don't see {'Sign out'}

  @T-0070-AC2
  Scenario: A double tap on Sign out asks the app once
    Given I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And I tap {'Sign out'} twice in quick succession
    Then the app was asked to sign out {1} time
    When the app signs the user out
    Then I see {'Not signed in'}

  @T-0070-AC2
  Scenario: A sign-out that breaks is reported, and the user stays signed in
    Given I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And I tap {'Sign out'}
    And signing out fails
    Then I see {'Signed in as Cole Collector'}
    And I see {'Sign out'}
    And {1} errors were reported
    When I tap {'Sign out'}
    Then the app was asked to sign out {2} times

  @T-0070-AC2
  Scenario: The session ends elsewhere: the index shows Not signed in
    Given I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And the session ends elsewhere
    Then I see {'Not signed in'}
    And I see {'Sign in'}

  @T-0070-AC2
  Scenario: Another user signs in while the index is open: it shows the new user
    Given I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And {'reader@mini-client.test'} signs in elsewhere
    Then I see {'Signed in as Rhea Reader'}
    And I see {'reader@mini-client.test'}
    And I don't see {'Signed in as Cole Collector'}
    And the session belongs to {'reader@mini-client.test'}

  @T-0070-AC2
  Scenario: The user switches while the first profile read is on its way: the late answer is dropped
    Given the backend holds the next {'GET /v1/me'}
    And I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And the app sends {'GET /v1/me'}
    Then I see {'Signed in as u-101'}
    When {'reader@mini-client.test'} signs in elsewhere
    Then I see {'Signed in as Rhea Reader'}
    When the backend releases {'GET /v1/me'}
    Then I see {'Signed in as Rhea Reader'}
    And I don't see {'Cole Collector'}
    And I don't see {'collector@mini-client.test'}
    And the backend received {2} requests for {'GET /v1/me'}
    And no error was reported

  @T-0070-AC2
  Scenario: Signing out while the profile read is on its way: the late answer does not bring the user back
    Given the backend holds the next {'GET /v1/me'}
    And I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And the app sends {'GET /v1/me'}
    And the session ends elsewhere
    Then I see {'Not signed in'}
    When the backend releases {'GET /v1/me'}
    Then I see {'Not signed in'}
    And I don't see {'Cole Collector'}

  @T-0070-AC3
  Scenario: The Appearance row asks the app to open the appearance settings
    When I open the settings
    And I tap {'Appearance'}
    Then the appearance settings were opened {1} time
    And I see {'Appearance'}

  @T-0070-AC4
  Scenario: In German every string of the index is German
    Given the device locale is {'de'}
    And I am signed in as {'collector@mini-client.test'}
    When I open the settings
    Then I see the texts
      | 'text'                       |
      | 'Einstellungen'              |
      | 'Konto'                      |
      | 'Angemeldet als Cole Collector' |
      | 'Abmelden'                   |
      | 'Darstellung'                |
      | 'System'                     |
      | 'Info'                       |
      | 'Build'                      |
      | 'Seed des simulierten Backends' |
    When the session ends elsewhere
    Then I see the texts
      | 'text'             |
      | 'Nicht angemeldet' |
      | 'Anmelden'         |
    When the theme mode is changed elsewhere to {'dark'}
    Then the row {'appearance'} reads {'Dunkel'}
    When the theme mode is changed elsewhere to {'light'}
    Then the row {'appearance'} reads {'Hell'}

  @T-0070-AC4
  Scenario Outline: In the pseudo-locale nothing overflows at <scale>x text
    Given the pseudo-locale is active
    And the text scale is {<scale>}
    And I am signed in as {'collector@mini-client.test'}
    When I open the settings
    And I scroll through the settings
    Then nothing overflows
    When the session ends elsewhere
    And I scroll through the settings
    Then nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |
