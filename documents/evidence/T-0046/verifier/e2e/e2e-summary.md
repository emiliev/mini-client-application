# E2E summary: T-0046 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0046 |
| Role | verifier |
| Project | `/tmp/mc-T-0046-verifier-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0046-verifier-70220` |
| Simulator UDID | `C092E270-E9B9-4B00-8CEC-2A3F006F9245` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-26T23:46:20Z |
| Finished | 2026-11-26T23:50:53Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/characters_deeplink_test.dart` | PASS | 39 s | [e2e-characters_deeplink_test.log](e2e-characters_deeplink_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 29 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/characters_link_after_flow_test.dart` | PASS | 23 s | [e2e-characters_link_after_flow_test.log](e2e-characters_link_after_flow_test.log) |
| `integration_test/comic_deeplink_test.dart` | PASS | 31 s | [e2e-comic_deeplink_test.log](e2e-comic_deeplink_test.log) |
| `integration_test/comics_journey_test.dart` | PASS | 34 s | [e2e-comics_journey_test.log](e2e-comics_journey_test.log) |
| `integration_test/search_deeplink_test.dart` | PASS | 28 s | [e2e-search_deeplink_test.log](e2e-search_deeplink_test.log) |
| `integration_test/search_journey_test.dart` | PASS | 35 s | [e2e-search_journey_test.log](e2e-search_journey_test.log) |
| `integration_test/zz_verifier_search_probe_test.dart` | PASS | 33 s | [e2e-zz_verifier_search_probe_test.log](e2e-zz_verifier_search_probe_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [05_deep_link_characters.png](05_deep_link_characters.png) | `integration_test/characters_deeplink_test.dart` | downscaled from 1206x2622 |
| [01_home.png](01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [06_link_after_flow.png](06_link_after_flow.png) | `integration_test/characters_link_after_flow_test.dart` | downscaled from 1206x2622 |
| [18_deep_link_comic.png](18_deep_link_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [19_link_to_running_app_comic.png](19_link_to_running_app_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [20_bad_comic_link_not_found.png](20_bad_comic_link_not_found.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [10_home.png](10_home.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [11_characters_list.png](11_characters_list.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [12_preview_related_comics.png](12_preview_related_comics.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [13_comic_page.png](13_comic_page.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [14_sign_in_sheet.png](14_sign_in_sheet.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [15_favourite_saved.png](15_favourite_saved.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [16_comic_cast.png](16_comic_cast.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [17_cast_member_placeholder.png](17_cast_member_placeholder.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [36_deep_link_search.png](36_deep_link_search.png) | `integration_test/search_deeplink_test.dart` | downscaled from 1206x2622 |
| [37_link_to_running_app_search.png](37_link_to_running_app_search.png) | `integration_test/search_deeplink_test.dart` | downscaled from 1206x2622 |
| [30_home_search_entry.png](30_home_search_entry.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [31_search_opened.png](31_search_opened.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [32_search_results_grouped.png](32_search_results_grouped.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [33_search_comics_chip.png](33_search_comics_chip.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [34_comic_from_search.png](34_comic_from_search.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [35_recent_searches.png](35_recent_searches.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [v01_blank_query_link.png](v01_blank_query_link.png) | `integration_test/zz_verifier_search_probe_test.dart` | downscaled from 1206x2622 |
| [v02_back_to_results.png](v02_back_to_results.png) | `integration_test/zz_verifier_search_probe_test.dart` | downscaled from 1206x2622 |
