# E2E summary: T-0037 (engineer)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0037 |
| Role | engineer |
| Project | `/tmp/mc-T-0037-engineer-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0037-engineer-75705` |
| Simulator UDID | `E3ADA7A4-AEB7-4852-9703-19A36942B0C4` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-26T06:23:56Z |
| Finished | 2026-11-26T06:25:36Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/characters_deeplink_test.dart` | PASS | 40 s | [e2e-characters_deeplink_test.log](e2e-characters_deeplink_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 24 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/characters_link_after_flow_test.dart` | PASS | 19 s | [e2e-characters_link_after_flow_test.log](e2e-characters_link_after_flow_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [05_deep_link_characters.png](05_deep_link_characters.png) | `integration_test/characters_deeplink_test.dart` | downscaled from 1206x2622 |
| [01_home.png](01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [06_link_after_flow.png](06_link_after_flow.png) | `integration_test/characters_link_after_flow_test.dart` | downscaled from 1206x2622 |
