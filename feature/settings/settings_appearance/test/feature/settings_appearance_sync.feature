Feature: The appearance follows the account
  Signed out, the choice lives on the device, and "Sync across devices" asks
  the app to sign in. On sign-in the account's values win, unless a change
  made here has not been synced yet. A failed sync never blocks a change, and
  another user's choice never shows for the user signed in now.

  Background:
    Given the backend serves {'identity.default'}

  @T-0063-AC3 @smoke
  Scenario: Signed out, Sync across devices waits for sign-in, then the account's values show
    When I open the appearance settings
    And I tap {'Sync across devices'}
    Then the app was asked to sign in {1} time
    And the sync status reads {'Waiting for you to sign in.'}
    When signing in succeeds as {'collector@mini-client.test'}
    Then the theme mode is {'Dark'}
    And the sync status reads {'Synced with your account.'}
    And the backend received {1} requests for {'GET /v1/me/preferences'}
    And the backend received {0} requests for {'PATCH /v1/me/preferences'}

  @T-0063-AC3
  Scenario: A choice made signed out goes to the account that signs in, over its value
    When I open the appearance settings
    And I choose the theme mode {'Light'}
    And I tap {'Sync across devices'}
    And signing in succeeds as {'collector@mini-client.test'}
    Then the theme mode is {'Light'}
    And the preferences writes were {'[{"ifVersion": 0, "themeMode": "light"}]'}
    And the account of {'collector@mini-client.test'} holds {'themeMode'} {'"light"'}
    And the sync status reads {'Synced with your account.'}

  @T-0063-AC3
  Scenario: Backing out of sign-in keeps the choice on the device and sends nothing
    When I open the appearance settings
    And I tap {'Sync across devices'}
    And signing in is cancelled
    Then the sync status reads {'Saved on this device.'}
    And I see {'Sync across devices'}
    And the app was asked to sign in {1} time
    And the backend received {0} requests for {'* /v1/me/preferences'}

  @T-0063-AC3
  Scenario: Signing in fails: the error is reported, and Sync across devices can be tapped again (review round)
    When I open the appearance settings
    And I tap {'Sync across devices'}
    And signing in fails
    Then the sync status reads {'Saved on this device.'}
    And {1} errors were reported
    When I tap {'Sync across devices'}
    Then the app was asked to sign in {2} times
    And the sync status reads {'Waiting for you to sign in.'}
    When signing in is cancelled
    Then the sync status reads {'Saved on this device.'}

  @T-0063-AC3
  Scenario: A double tap on Sync across devices asks to sign in once
    When I open the appearance settings
    And I tap {'Sync across devices'} twice in quick succession
    Then the app was asked to sign in {1} time
    When signing in is cancelled
    Then I see {'Sync across devices'}

  @T-0063-AC2 @smoke
  Scenario: The account preferences fail: the device's values show, the status says offline, a change still applies, and Retry syncs
    Given the backend runs the scenario {'identity.preferences_error'}
    And I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    Then the theme mode is {'System'}
    And the sync status reads {'Not synced. Your choice is kept on this device.'}
    When I choose the theme mode {'Light'}
    Then the theme mode is {'Light'}
    And the app uses {'light'} {'comfortable'} with reduce motion {'off'}
    And the sync status reads {'Not synced. Your choice is kept on this device.'}
    And the backend received {6} requests for {'GET /v1/me/preferences'}
    And the backend received {0} requests for {'PATCH /v1/me/preferences'}
    When the backend recovers
    And I tap {'Retry'}
    Then the sync status reads {'Synced with your account.'}
    And the theme mode is {'Light'}
    And the backend received {7} requests for {'GET /v1/me/preferences'}
    And the preferences writes were {'[{"ifVersion": 0, "themeMode": "light"}]'}
    And the account of {'collector@mini-client.test'} holds {'themeMode'} {'"light"'}

  @T-0063-AC2
  Scenario: A version conflict re-applies the change on the new version, with exactly 2 PATCHes, and ends synced
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And the backend runs the scenario {'identity.preferences_conflict'}
    And I switch reduce motion {'on'}
    Then the backend received {2} requests for {'PATCH /v1/me/preferences'}
    And the preferences writes were {'[{"ifVersion": 0, "reduceMotion": true}, {"ifVersion": 0, "reduceMotion": true}]'}
    And the sync status reads {'Synced with your account.'}
    And the theme mode is {'Dark'}
    And reduce motion is {'on'}
    And the account of {'collector@mini-client.test'} holds {'reduceMotion'} {'true'}
    And the account of {'collector@mini-client.test'} holds {'version'} {'1'}

  @T-0063-AC2
  Scenario: Another device changed another setting: it is kept, the change goes on top, and the status says so
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And another device of {'collector@mini-client.test'} sets {'density'} {'"compact"'}
    And I choose the theme mode {'Light'}
    Then the preferences writes were {'[{"ifVersion": 0, "themeMode": "light"}, {"ifVersion": 1, "themeMode": "light"}]'}
    And the theme mode is {'Light'}
    And the density is {'Compact'}
    And the sync status reads {'Synced. A change from another device was kept too.'}

  @T-0063-AC6
  Scenario: Another user signs in right before the change is sent: it never leaves, and that user's values show
    Given I am signed in as {'collector@mini-client.test'}
    And {'reader@mini-client.test'} signs in just before the app sends {'PATCH /v1/me/preferences'}
    When I open the appearance settings
    And I choose the theme mode {'Light'}
    And the app finishes writing to storage
    Then the session belongs to {'reader@mini-client.test'}
    And the theme mode is {'System'}
    And the app uses {'system'} {'comfortable'} with reduce motion {'off'}
    And the backend received {0} requests for {'PATCH /v1/me/preferences'}
    And the account of {'collector@mini-client.test'} holds {'themeMode'} {'"dark"'}
    And the account of {'reader@mini-client.test'} holds {'version'} {'0'}
    And no error was reported

  @T-0063-AC6
  Scenario: Another user signs in while the change is on its way: its late answer changes nothing, and that user's values show
    Given I am signed in as {'collector@mini-client.test'}
    And the backend holds the next {'PATCH /v1/me/preferences'}
    When I open the appearance settings
    And I choose the theme mode {'Light'}
    And the app sends {'PATCH /v1/me/preferences'}
    And {'reader@mini-client.test'} signs in elsewhere
    Then the theme mode is {'System'}
    When the backend releases {'PATCH /v1/me/preferences'}
    Then the theme mode is {'System'}
    And the app uses {'system'} {'comfortable'} with reduce motion {'off'}
    And the sync status reads {'Synced with your account.'}
    And the account of {'collector@mini-client.test'} holds {'themeMode'} {'"light"'}
    And the account of {'reader@mini-client.test'} holds {'version'} {'0'}
    And no error was reported

  @T-0063-AC6
  Scenario: Signing out keeps the last values on this device
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And the session ends elsewhere
    Then the theme mode is {'Dark'}
    And the sync status reads {'Saved on this device.'}
    And I see {'Sync across devices'}

  @T-0063-AC4
  Scenario: In German every string of both pages is German
    Given the device locale is {'de'}
    When I open the appearance settings
    Then I see the texts
      | 'text'                                |
      | 'Darstellung'                         |
      | 'Design'                              |
      | 'System'                              |
      | 'Hell'                                |
      | 'Dunkel'                              |
      | 'Dichte'                              |
      | 'Komfortabel'                         |
      | 'Kompakt'                             |
      | 'Bewegung reduzieren'                 |
      | 'Schaltet die Animationen der App aus.' |
      | 'Auf diesem Gerät gespeichert.'       |
      | 'Auf allen Geräten synchronisieren'   |
      | 'Über Designs'                        |
      | 'Auf Standard zurücksetzen'           |
    When I tap {'Auf Standard zurücksetzen'}
    Then I see {'Darstellung zurücksetzen?'}
    And I see {'Zurücksetzen'}
    When I cancel the dialog
    And I tap {'Über Designs'}
    Then I see {'Kompakt zeigt mehr auf dem Bildschirm, mit engeren Abständen.'}

  @T-0063-AC4
  Scenario Outline: In the pseudo-locale nothing overflows at <scale>x text
    Given the pseudo-locale is active
    And the text scale is {<scale>}
    And I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And I scroll through the settings
    Then nothing overflows
    When I tap {'[Àƀóúţ ţĥéɱéš ~~~~]'}
    Then the explainer is open
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |
