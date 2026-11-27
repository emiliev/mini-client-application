# E2E summary: T-0055 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0055 |
| Role | verifier |
| Project | `/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/v55/proj/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0055-verifier-45899` |
| Simulator UDID | `96D06F47-55A4-454E-911F-63A269D9244E` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-27T11:31:24Z |
| Finished | 2026-11-27T11:33:33Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/characters_journey_test.dart` | PASS | 46 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/comic_deeplink_test.dart` | PASS | 34 s | [e2e-comic_deeplink_test.log](e2e-comic_deeplink_test.log) |
| `integration_test/analytics_screens_test.dart` | PASS | 24 s | [e2e-analytics_screens_test.log](e2e-analytics_screens_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [01_home.png](01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [18_deep_link_comic.png](18_deep_link_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [18b_back_from_comic_is_home.png](18b_back_from_comic_is_home.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [19_link_to_running_app_comic.png](19_link_to_running_app_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [20_bad_comic_link_not_found.png](20_bad_comic_link_not_found.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [analytics_screens_test-01_home.png](analytics_screens_test-01_home.png) | `integration_test/analytics_screens_test.dart` | downscaled from 1206x2622 |
| [analytics_screens_test-02_characters_list.png](analytics_screens_test-02_characters_list.png) | `integration_test/analytics_screens_test.dart` | downscaled from 1206x2622 |
| [03_back_to_home.png](03_back_to_home.png) | `integration_test/analytics_screens_test.dart` | downscaled from 1206x2622 |
