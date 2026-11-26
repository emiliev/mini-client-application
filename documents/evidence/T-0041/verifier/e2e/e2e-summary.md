# E2E summary: T-0041 (verifier)

| Field | Value |
|---|---|
| Result | **FAIL** |
| Task | T-0041 |
| Role | verifier |
| Project | `/tmp/mc-T-0041-verifier-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0041-verifier-55504` |
| Simulator UDID | `3B1DECB4-D73B-4EA7-B901-9CA02414D89B` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-26T18:54:00Z |
| Finished | 2026-11-26T18:57:12Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/comics_journey_test.dart` | PASS | 52 s | [e2e-comics_journey_test.log](e2e-comics_journey_test.log) |
| `integration_test/comic_deeplink_test.dart` | PASS | 27 s | [e2e-comic_deeplink_test.log](e2e-comic_deeplink_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 29 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/verifier_probe_test.dart` | FAIL | 59 s | [e2e-verifier_probe_test.log](e2e-verifier_probe_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [10_home.png](10_home.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [11_characters_list.png](11_characters_list.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [12_preview_related_comics.png](12_preview_related_comics.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [13_comic_page.png](13_comic_page.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [14_sign_in_sheet.png](14_sign_in_sheet.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [15_favourite_saved.png](15_favourite_saved.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [16_comic_cast.png](16_comic_cast.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [17_cast_member_placeholder.png](17_cast_member_placeholder.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [18_deep_link_comic.png](18_deep_link_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [19_link_to_running_app_comic.png](19_link_to_running_app_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [20_bad_comic_link_not_found.png](20_bad_comic_link_not_found.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [01_home.png](01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [v01_back_to_preview.png](v01_back_to_preview.png) | `integration_test/verifier_probe_test.dart` | downscaled from 1206x2622 |
| [v02_back_to_list.png](v02_back_to_list.png) | `integration_test/verifier_probe_test.dart` | downscaled from 1206x2622 |
| [v03_after_drag_while_signing_in.png](v03_after_drag_while_signing_in.png) | `integration_test/verifier_probe_test.dart` | downscaled from 1206x2622 |
