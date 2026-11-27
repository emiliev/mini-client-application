# E2E summary: T-0049 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0049 |
| Role | verifier |
| Project | `/tmp/mc-T-0049-verifier-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0049-verifier-95721` |
| Simulator UDID | `E8F6431F-8CF7-4B08-9E5B-E45890ED81EA` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-27T06:56:26Z |
| Finished | 2026-11-27T07:04:54Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/v0_running_probes_test.dart` | PASS | 70 s | [e2e-v0_running_probes_test.log](e2e-v0_running_probes_test.log) |
| `integration_test/character_details_deeplink_test.dart` | PASS | 26 s | [e2e-character_details_deeplink_test.log](e2e-character_details_deeplink_test.log) |
| `integration_test/characters_deeplink_test.dart` | PASS | 34 s | [e2e-characters_deeplink_test.log](e2e-characters_deeplink_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 32 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/characters_link_after_flow_test.dart` | PASS | 27 s | [e2e-characters_link_after_flow_test.log](e2e-characters_link_after_flow_test.log) |
| `integration_test/comic_deeplink_test.dart` | PASS | 30 s | [e2e-comic_deeplink_test.log](e2e-comic_deeplink_test.log) |
| `integration_test/comics_journey_test.dart` | PASS | 40 s | [e2e-comics_journey_test.log](e2e-comics_journey_test.log) |
| `integration_test/reading_list_deeplink_test.dart` | PASS | 27 s | [e2e-reading_list_deeplink_test.log](e2e-reading_list_deeplink_test.log) |
| `integration_test/reading_list_journey_test.dart` | PASS | 36 s | [e2e-reading_list_journey_test.log](e2e-reading_list_journey_test.log) |
| `integration_test/search_deeplink_test.dart` | PASS | 32 s | [e2e-search_deeplink_test.log](e2e-search_deeplink_test.log) |
| `integration_test/search_journey_test.dart` | PASS | 36 s | [e2e-search_journey_test.log](e2e-search_journey_test.log) |
| `integration_test/v1_cold_edit_test.dart` | PASS | 25 s | [e2e-v1_cold_edit_test.log](e2e-v1_cold_edit_test.log) |
| `integration_test/v2_cold_query_fragment_test.dart` | PASS | 23 s | [e2e-v2_cold_query_fragment_test.log](e2e-v2_cold_query_fragment_test.log) |
| `integration_test/v3_cold_bad_comic_test.dart` | PASS | 23 s | [e2e-v3_cold_bad_comic_test.log](e2e-v3_cold_bad_comic_test.log) |
| `integration_test/v4_cold_unknown_test.dart` | PASS | 23 s | [e2e-v4_cold_unknown_test.log](e2e-v4_cold_unknown_test.log) |

## Screenshots

The run took 52 screenshots (all looked at). Four are kept here, as the report says: `55_deep_link_character_details.png`, `55b_back_from_details_is_list.png`, `55c_back_from_list_is_home.png`, `v3_cold_bad_comic.png`.
