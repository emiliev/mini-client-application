# E2E summary: T-0056 (engineer)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0056 |
| Role | engineer |
| Project | `/tmp/mc-T-0056-engineer-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0056-engineer-18159` |
| Simulator UDID | `ADBB42DD-3E2A-4F4D-B9C1-F665DFF82512` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-27T11:20:11Z |
| Finished | 2026-11-27T11:22:48Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/store_journey_test.dart` | PASS | 68 s | [e2e-store_journey_test.log](e2e-store_journey_test.log) |
| `integration_test/store_deeplink_test.dart` | PASS | 31 s | [e2e-store_deeplink_test.log](e2e-store_deeplink_test.log) |
| `integration_test/store_category_deeplink_test.dart` | PASS | 34 s | [e2e-store_category_deeplink_test.log](e2e-store_category_deeplink_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [40_home_store_entry.png](40_home_store_entry.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [41_store_sections.png](41_store_sections.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [42_store_lower_sections.png](42_store_lower_sections.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [43_comic_from_deal.png](43_comic_from_deal.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [44_back_to_store.png](44_back_to_store.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [45_category_heroes.png](45_category_heroes.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [46_category_page_two.png](46_category_page_two.png) | `integration_test/store_journey_test.dart` | downscaled from 1206x2622 |
| [47_deep_link_store.png](47_deep_link_store.png) | `integration_test/store_deeplink_test.dart` | downscaled from 1206x2622 |
| [47b_back_from_store_is_home.png](47b_back_from_store_is_home.png) | `integration_test/store_deeplink_test.dart` | downscaled from 1206x2622 |
| [48_deep_link_category.png](48_deep_link_category.png) | `integration_test/store_category_deeplink_test.dart` | downscaled from 1206x2622 |
| [48b_back_from_category_is_store.png](48b_back_from_category_is_store.png) | `integration_test/store_category_deeplink_test.dart` | downscaled from 1206x2622 |
| [48c_back_from_store_is_home.png](48c_back_from_store_is_home.png) | `integration_test/store_category_deeplink_test.dart` | downscaled from 1206x2622 |
