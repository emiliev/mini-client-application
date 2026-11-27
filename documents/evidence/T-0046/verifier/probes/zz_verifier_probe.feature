Feature: Verifier probes (temporary)

  Background:
    Given the backend serves {'discovery.default'}

  Scenario: P1 storage made read-only keeps reads and blocks writes
    When I open the search
    And I type {'amber'}
    And the app finishes writing to storage
    Given the app can no longer write to storage
    Then the read-only storage still reads and refuses a write
    When I open the search again
    Then the recent searches are {'amber'}

  Scenario: P2 the previous scenario left nothing behind
    Then no read-only storage copy or link is left behind

  Scenario: P3 a too-short answer is logged, not reported
    When I open the search
    And I type {'é'}
    Then no error was reported
    And the backend received {1} requests for {'GET /v1/search'}
    And the probe prints the monitoring logs

  Scenario: P4 a keyboard search action searches at once
    When I open the search
    And I type {'spi'} one character at a time
    And I press the keyboard search action
    Then the backend received {0} requests for {'GET /v1/search'}
