Feature: The reading list editor speaks the reader's language
  Every step title, label, validation message and button comes from the
  feature's own strings, in German as in English, and long translations fit
  on every step at large text sizes.

  Background:
    Given the backend serves {'comics.default'}
    And the backend serves {'identity.default'}
    And the backend serves {'library.default'}

  @T-0048-AC4 @l10n
  Scenario: In German every step, label, message and button is German
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    Then I see the texts
      | 'text'                                                          |
      | 'Neue Leseliste'                                                |
      | 'Schritt 1 von 3'                                               |
      | 'Details'                                                       |
      | 'Gib deiner Liste einen Namen und wähle, wer sie sehen kann.'  |
      | 'Name'                                                          |
      | 'Beschreibung (optional)'                                       |
      | 'Wer sie sehen kann'                                            |
      | 'Privat'                                                        |
      | 'Öffentlich'                                                    |
      | 'Zurück'                                                        |
      | 'Weiter'                                                        |
    When I tap {'Weiter'}
    Then the error {'Gib deiner Liste einen Namen.'} shows under the field {'Name'}
    When I enter {'Amber'} in the field {'Name'}
    And I enter {'ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'} in the field {'Beschreibung (optional)'}
    Then the error {'Verwende höchstens 280 Zeichen.'} shows under the field {'Beschreibung (optional)'}
    When I enter {''} in the field {'Beschreibung (optional)'}
    And I tap {'Weiter'}
    Then I see the texts
      | 'text'                         |
      | 'Comics auswählen'             |
      | 'Schritt 2 von 3'              |
      | 'Noch keine Comics ausgewählt' |
    When I tap {'Weiter'}
    Then the comics error reads {'Wähle mindestens einen Comic aus.'}
    When I pick {'Amber Chronicles #1'}
    Then I see {'1 Comic ausgewählt'}
    When I tap {'Weiter'}
    Then I see the texts
      | 'text'                                                                    |
      | 'Reihenfolge und Übersicht'                                               |
      | 'Schritt 3 von 3'                                                         |
      | 'Keine Beschreibung'                                                      |
      | 'Lesereihenfolge'                                                         |
      | 'Ziehe einen Comic oder nutze die Pfeile, um die Reihenfolge zu ändern.' |
      | 'Liste erstellen'                                                         |
    Given the backend fails {'POST /v1/me/lists'} with {'server_error'}
    When I tap {'Liste erstellen'}
    Then I see the texts
      | 'text'                                                                       |
      | 'Die Liste konnte nicht gespeichert werden'                                  |
      | 'Auf dem Server ist ein Fehler aufgetreten. Bitte versuche es später erneut.' |
      | 'Erneut versuchen'                                                           |

  @T-0048-AC4 @l10n
  Scenario: In German, editing and the states around it are German
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor for {'l-1'}
    Then I see {'Leseliste bearbeiten'}
    When I tap {'Weiter'}
    Then I see {'3 Comics ausgewählt'}
    When I tap {'Weiter'}
    Then I see {'Änderungen speichern'}
    When the session ends elsewhere
    Then I see the texts
      | 'text'                                                                                       |
      | 'Du bist nicht mehr wie zuvor angemeldet'                                                    |
      | 'Das Konto hat sich während der Bearbeitung geändert, daher wurde nichts weiter gespeichert.' |
      | 'Schließen'                                                                                  |

  @T-0048-AC4 @l10n
  Scenario: In German a list that is not the reader's is "not found"
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor for {'l-4'}
    Then I see the texts
      | 'text'                                                  |
      | 'Liste nicht gefunden'                                  |
      | 'Diese Leseliste gibt es nicht, oder sie gehört dir nicht.' |

  @T-0048-AC4 @l10n
  Scenario Outline: In the pseudo-locale nothing overflows on any step at <scale>x
    Given the pseudo-locale is active
    And the text scale is <scale>
    And I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    Then nothing overflows
    When I tap {'[Ñéxţ ~~]'}
    Then I see {'[Ĝívé ýóúŕ ļíšţ à ñàɱé. ~~~~~~~~~]'}
    And nothing overflows
    When I enter {'Amber reads'} in the field {'[Ñàɱé ~~]'}
    And I tap {'[Þúƀļíç ~~]'}
    And I tap {'[Ñéxţ ~~]'}
    Then I see {'[Þíçķ çóɱíçš ~~~~]'}
    When I tap {'[Ñéxţ ~~]'}
    Then the comics error reads {'[Þíçķ àţ ļéàšţ óñé çóɱíç. ~~~~~~~~~~]'}
    And nothing overflows
    When I pick {'Amber Chronicles #1'}
    And I pick {'Amber Chronicles #2'}
    And I tap {'[Ñéxţ ~~]'}
    Then I see {'[Óŕðéŕ àñð ŕévíéŵ ~~~~~~]'}
    And nothing overflows
    Given the backend fails {'POST /v1/me/lists'} with {'server_error'}
    When I tap {'[Çŕéàţé ļíšţ ~~~~]'}
    Then I see {'[Ţĥé ļíšţ çóúļð ñóţ ƀé šàvéð ~~~~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0048-AC4 @l10n
  Scenario Outline: In the pseudo-locale the states outside the wizard fit at <scale>x
    Given the pseudo-locale is active
    And the text scale is <scale>
    When I open the reading list editor
    Then nothing overflows
    When signing in succeeds as {'reader@mini-client.test'}
    And the session ends elsewhere
    Then nothing overflows
    When I tap {'[Çļóšé ~~]'}
    Then the editor ended without a list

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0050-AC3 @l10n
  Scenario: In German the backend's refusal of a name is German, under the name
    Given the device locale is {'de'}
    And I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor
    And I enter {' weekend reads '} as the name
    And I tap {'Weiter'}
    And I pick {'Amber Chronicles #1'}
    And I tap {'Weiter'}
    And I tap {'Liste erstellen'}
    Then the backend answered {'POST /v1/me/lists'} with {400}
    And I see {'Schritt 1 von 3'}
    And the error {'Du hast schon eine Liste mit diesem Namen. Bitte wähle einen anderen.'} shows under the field {'Name'}

  @T-0050-AC3 @l10n
  Scenario Outline: In the pseudo-locale a list that is not the reader's fits at <scale>x
    Given the pseudo-locale is active
    And the text scale is <scale>
    And I am signed in as {'reader@mini-client.test'}
    When I open the reading list editor for {'l-4'}
    Then I see {'[Ļíšţ ñóţ ƒóúñð ~~~~~~]'}
    And I see {'[Ţĥíš ŕéàðíñĝ ļíšţ ðóéš ñóţ éxíšţ óŕ íš ñóţ ýóúŕš. ~~~~~~~~~~~~~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |

  @T-0050-AC3 @l10n
  Scenario Outline: In the pseudo-locale a list that could not be loaded fits at <scale>x
    Given the pseudo-locale is active
    And the text scale is <scale>
    And I am signed in as {'reader@mini-client.test'}
    And the backend fails {'GET /v1/me/lists/l-1'} with {'server_error'}
    When I open the reading list editor for {'l-1'}
    Then I see {'[Ţĥé ŕéàðíñĝ ļíšţ çóúļð ñóţ ƀé ļóàðéð ~~~~~~~~~~~~~~]'}
    And nothing overflows

    Examples:
      | scale |
      | 1     |
      | 2     |
