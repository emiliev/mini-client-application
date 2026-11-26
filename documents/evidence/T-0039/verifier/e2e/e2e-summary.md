# E2E summary: T-0039 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0039 |
| Role | verifier |
| Project | `/tmp/mc-T-0039-verifier-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0039-verifier-64974` |
| Simulator UDID | `CCA67B13-446A-4CEB-ABE4-03A18DF3FC2C` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-26T15:02:10Z |
| Finished | 2026-11-26T15:04:34Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/verifier_session_restore_t0039_test.dart` | PASS | 48 s | [e2e-verifier_session_restore_t0039_test.log](e2e-verifier_session_restore_t0039_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 30 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/characters_deeplink_test.dart` | PASS | 26 s | [e2e-characters_deeplink_test.log](e2e-characters_deeplink_test.log) |
| `integration_test/characters_link_after_flow_test.dart` | PASS | 21 s | [e2e-characters_link_after_flow_test.log](e2e-characters_link_after_flow_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [01_home_with_restored_session.png](01_home_with_restored_session.png) | `integration_test/verifier_session_restore_t0039_test.dart` | downscaled from 1206x2622 |
| [01_home.png](01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [05_deep_link_characters.png](05_deep_link_characters.png) | `integration_test/characters_deeplink_test.dart` | downscaled from 1206x2622 |
| [06_link_after_flow.png](06_link_after_flow.png) | `integration_test/characters_link_after_flow_test.dart` | downscaled from 1206x2622 |
