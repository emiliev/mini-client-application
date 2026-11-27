Feature: Appearance settings
  You choose the theme mode, the density and Reduce motion. The whole app uses
  the choice at once, it is kept on the device, and signed in it follows you
  through your account.

  Background:
    Given the backend serves {'identity.default'}

  @T-0063-AC1 @smoke
  Scenario: With the defaults, Appearance shows System, Comfortable and Reduce motion off
    When I open the appearance settings
    Then the theme mode is {'System'}
    And the density is {'Comfortable'}
    And reduce motion is {'off'}
    And the sync status reads {'Saved on this device.'}
    And I see {'Sync across devices'}
    And the backend received {0} requests for {'GET /v1/me/preferences'}

  @T-0063-AC1
  Scenario: Signed in as the collector, Appearance shows Dark, the account's seed
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    Then the theme mode is {'Dark'}
    And the density is {'Comfortable'}
    And the app uses {'dark'} {'comfortable'} with reduce motion {'off'}
    And the sync status reads {'Synced with your account.'}
    And I don't see {'Sync across devices'}
    And the backend received {1} requests for {'GET /v1/me/preferences'}
    And the backend received {0} requests for {'PATCH /v1/me/preferences'}

  @T-0063-AC6
  Scenario: Signed out, a choice applies app-wide at once and is kept on the device
    When I open the appearance settings
    And I choose the theme mode {'Dark'}
    And I choose the density {'Compact'}
    And I switch reduce motion {'on'}
    Then the theme mode is {'Dark'}
    And the density is {'Compact'}
    And reduce motion is {'on'}
    And the app uses {'dark'} {'compact'} with reduce motion {'on'}
    And the device keeps {'dark'} {'compact'} with reduce motion {'on'}
    And the backend received {0} requests for {'* /v1/me/preferences'}

  @T-0063-AC6
  Scenario: Signed in, a choice goes to the account with its version and only its own setting
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And I choose the theme mode {'Light'}
    Then the app uses {'light'} {'comfortable'} with reduce motion {'off'}
    And the sync status reads {'Synced with your account.'}
    And the preferences writes were {'[{"ifVersion": 0, "themeMode": "light"}]'}
    And the account of {'collector@mini-client.test'} holds {'themeMode'} {'"light"'}

  @T-0063-AC6
  Scenario: Choosing the value already chosen saves, sends and tracks nothing
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And I choose the theme mode {'Dark'}
    And I choose the density {'Comfortable'}
    Then the backend received {0} requests for {'PATCH /v1/me/preferences'}
    And the settings changes tracked are {''}

  @T-0063-AC6
  Scenario: Each change is tracked once with its setting and value
    When I open the appearance settings
    And I choose the theme mode {'Dark'}
    And I choose the density {'Compact'}
    And I switch reduce motion {'on'}
    And I switch reduce motion {'off'}
    Then the settings changes tracked are {'theme_mode=dark, density=compact, reduce_motion=true, reduce_motion=false'}
    And the analytics event {'settings_changed'} was tracked with
      | 'key'     | 'json'   |
      | 'setting' | '"theme_mode"' |
      | 'value'   | '"dark"' |

  @T-0063-AC3
  Scenario: The explainer opens in the flow, and Back returns to the settings
    When I open the appearance settings
    And I tap {'About themes'}
    Then the explainer is open
    And I see {'Compact fits more on the screen by tightening the spacing.'}
    When I go back
    Then the theme mode is {'System'}
    And the screens tracked are {'settings_appearance, settings_appearance_about, settings_appearance'}

  @T-0063-AC3
  Scenario: Reset asks first, and Cancel changes nothing
    When I open the appearance settings
    And I choose the theme mode {'Dark'}
    And I choose the density {'Compact'}
    And I tap {'Reset to defaults'}
    Then I see {'Reset the appearance?'}
    When I cancel the dialog
    Then the theme mode is {'Dark'}
    And the density is {'Compact'}
    And the settings changes tracked are {'theme_mode=dark, density=compact'}

  @T-0063-AC3
  Scenario: Confirming the reset restores the defaults and syncs them
    Given I am signed in as {'collector@mini-client.test'}
    When I open the appearance settings
    And I choose the density {'Compact'}
    And I switch reduce motion {'on'}
    And I tap {'Reset to defaults'}
    And I confirm the dialog
    Then the theme mode is {'System'}
    And the density is {'Comfortable'}
    And reduce motion is {'off'}
    And the app uses {'system'} {'comfortable'} with reduce motion {'off'}
    And the settings changes tracked are {'density=compact, reduce_motion=true, reset=defaults'}
    And the account of {'collector@mini-client.test'} holds {'themeMode'} {'"system"'}
    And the account of {'collector@mini-client.test'} holds {'reduceMotion'} {'false'}
    And the sync status reads {'Synced with your account.'}

  @T-0063-AC3
  Scenario: Confirming the reset when everything is already the default does nothing
    When I open the appearance settings
    And I tap {'Reset to defaults'}
    And I confirm the dialog
    Then the theme mode is {'System'}
    And the settings changes tracked are {''}

  @T-0063-AC6
  Scenario: The device cannot save: the choice applies, the screen says it was not saved, and Retry tries again
    When I open the appearance settings
    And the app can no longer write to storage
    And I choose the theme mode {'Dark'}
    Then the app uses {'dark'} {'comfortable'} with reduce motion {'off'}
    And I see {'Your choice applies now, but this device could not save it.'}
    When I tap {'Retry'}
    Then I see {'Not saved'}
