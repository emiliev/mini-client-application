Feature: The sign-in form speaks the reader's language
  Every title, label, message and button comes from the feature's own
  strings, in German as in English, and long translations fit at large text
  sizes.

  Background:
    Given the backend serves {'identity.default'}

  @T-0066-AC1 @l10n
  Scenario: In German the form, its errors and its helpers are German
    Given the device locale is {'de'}
    When I open the sign-in form with the demo accounts
    Then I see the texts
      | 'text'                                  |
      | 'Anmelden'                              |
      | 'Nutze dein Mini-Client-Konto.'         |
      | 'E-Mail'                                |
      | 'Passwort'                              |
      | 'Demokonto verwenden'                   |
      | 'Füllt das Formular mit einem Testkonto aus.' |
      | 'Rhea Reader (reader@mini-client.test)' |
      | 'Jetzt nicht'                           |
    When I submit the form
    Then the error {'Gib deine E-Mail-Adresse ein.'} shows under the field {'E-Mail'}
    And the error {'Gib dein Passwort ein.'} shows under the field {'Passwort'}
    When I enter {'reader'} in the field {'E-Mail'}
    Then the error {'Gib eine gültige E-Mail-Adresse ein.'} shows under the field {'E-Mail'}
    When I enter {'reader@mini-client.test'} in the field {'E-Mail'}
    And I enter {'not-it'} in the field {'Passwort'}
    And I submit the form
    Then I see {'E-Mail oder Passwort ist falsch.'}

  @T-0066-AC1 @l10n
  Scenario: In German a failing backend is German, with a German retry
    Given the device locale is {'de'}
    And the backend fails {'POST /v1/auth/sign-in'} with {'server_error'}
    When I open the sign-in form
    And I enter {'reader@mini-client.test'} in the field {'E-Mail'}
    And I enter {'marvelous'} in the field {'Passwort'}
    And I submit the form
    Then I see {'Anmeldung nicht möglich. Auf dem Server ist ein Fehler aufgetreten. Bitte versuche es später erneut.'}
    And the submit button reads {'Erneut versuchen'}

  @T-0066-AC1 @l10n
  Scenario Outline: In German the reason line is German
    Given the device locale is {'de'}
    When I open the sign-in form for {<code>}
    Then I see {<line>}

    Examples:
      | code             | line                                                                       |
      | 'favourites'     | 'Melde dich an, um deine Favoriten zu behalten.'                           |
      | 'readingLists'   | 'Melde dich an, um deine Leselisten zu speichern.'                         |
      | 'cart'           | 'Melde dich an, um deinen Warenkorb zu nutzen.'                            |
      | 'triviaResults'  | 'Melde dich an, um deine Quizergebnisse zu behalten.'                      |
      | 'appearanceSync' | 'Melde dich an, um dein Erscheinungsbild auf allen Geräten zu synchronisieren.' |

  @T-0066-AC1 @l10n
  Scenario Outline: In the pseudo-locale nothing overflows at <scale>x
    Given the pseudo-locale is active
    And the text scale is <scale>
    When I open the sign-in form with the demo accounts
    Then nothing overflows
    When I submit the form
    Then the error {'[Éñţéŕ ýóúŕ éɱàíļ àððŕéšš. ~~~~~~~~~~]'} shows under the field {'[Éɱàíļ ~~]'}
    And nothing overflows
    When I enter {'reader@mini-client.test'} in the field {'[Éɱàíļ ~~]'}
    And I enter {'not-it'} in the field {'[Þàššŵóŕð ~~~]'}
    And I submit the form
    Then I see {'[Ţĥé éɱàíļ óŕ þàššŵóŕð íš ŵŕóñĝ. ~~~~~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0066-AC1 @l10n
  Scenario Outline: In the pseudo-locale a failing backend fits at <scale>x
    Given the pseudo-locale is active
    And the text scale is <scale>
    And the backend fails {'POST /v1/auth/sign-in'} with {'server_error'}
    When I open the sign-in form for {'appearanceSync'}
    And I enter {'reader@mini-client.test'} in the field {'[Éɱàíļ ~~]'}
    And I enter {'marvelous'} in the field {'[Þàššŵóŕð ~~~]'}
    And I submit the form
    Then I see {'[Çóúļð ñóţ šíĝñ íñ. [Ţĥé šéŕvéŕ ĥàð à þŕóþļéɱ. Þļéàšé ţŕý àĝàíñ ļàţéŕ. ~~~~~~~~~~~~~~~~~~] ~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |
