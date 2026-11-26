# E2E summary: T-0033 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0033 |
| Role | verifier |
| Project | `/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/verifier-T0033-r3/mini/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0033-verifier-23379` |
| Simulator UDID | `3C03893C-E76F-456A-8225-4E8DA22BE147` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-25T19:34:53Z |
| Finished | 2026-11-25T19:36:56Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/characters_deeplink_test.dart` | PASS | 30 s | [e2e-characters_deeplink_test.log](e2e-characters_deeplink_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 24 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/characters_link_after_flow_test.dart` | PASS | 19 s | [e2e-characters_link_after_flow_test.log](e2e-characters_link_after_flow_test.log) |
| `integration_test/verifier_warm_link_test.dart` | PASS | 33 s | [e2e-verifier_warm_link_test.log](e2e-verifier_warm_link_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [05_deep_link_characters.png](05_deep_link_characters.png) | `integration_test/characters_deeplink_test.dart` | downscaled from 1206x2622 |
| [01_home.png](01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [06_link_after_flow.png](06_link_after_flow.png) | `integration_test/characters_link_after_flow_test.dart` | downscaled from 1206x2622 |
| [rv_06_mini_warm_probe.png](rv_06_mini_warm_probe.png) | `integration_test/verifier_warm_link_test.dart` | downscaled from 1206x2622 |
| [rv_07_mini_warm_probe_from_list.png](rv_07_mini_warm_probe_from_list.png) | `integration_test/verifier_warm_link_test.dart` | downscaled from 1206x2622 |
