# E2E summary: T-0066 (engineer)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0066 |
| Role | engineer |
| Project | `/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ab19efba427986994/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0066-engineer-45844` |
| Simulator UDID | `6D3E510A-07C0-4DC5-A7DC-D770B73BFD92` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-27T19:38:51Z |
| Finished | 2026-11-27T19:43:11Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/auth_signin_journey_test.dart` | PASS | 72 s | [e2e-auth_signin_journey_test.log](e2e-auth_signin_journey_test.log) |
| `integration_test/reading_list_journey_test.dart` | PASS | 50 s | [e2e-reading_list_journey_test.log](e2e-reading_list_journey_test.log) |
| `integration_test/reading_list_deeplink_test.dart` | PASS | 37 s | [e2e-reading_list_deeplink_test.log](e2e-reading_list_deeplink_test.log) |
| `integration_test/comics_journey_test.dart` | PASS | 36 s | [e2e-comics_journey_test.log](e2e-comics_journey_test.log) |
| `integration_test/settings_signed_in_test.dart` | PASS | 27 s | [e2e-settings_signed_in_test.log](e2e-settings_signed_in_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [70_home_signed_out.png](70_home_signed_out.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [71_sign_in_form.png](71_sign_in_form.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [72_home_signed_in.png](72_home_signed_in.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [73_favourite_saved.png](73_favourite_saved.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [74_home_signed_out_again.png](74_home_signed_out_again.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [75_cold_link_sign_in.png](75_cold_link_sign_in.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [76_editor_after_sign_in.png](76_editor_after_sign_in.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [77_back_to_home.png](77_back_to_home.png) | `integration_test/auth_signin_journey_test.dart` | downscaled from 1206x2622 |
| [30_home_new_reading_list.png](30_home_new_reading_list.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [31_sign_in_form.png](31_sign_in_form.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [32_step1_blocked.png](32_step1_blocked.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [33_step1_details.png](33_step1_details.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [34_step2_comics.png](34_step2_comics.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [35_step3_review.png](35_step3_review.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [36_home_list_created.png](36_home_list_created.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [36b_guard_sign_in_form.png](36b_guard_sign_in_form.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [37_deep_link_new_list.png](37_deep_link_new_list.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [37b_back_from_new_list_is_home.png](37b_back_from_new_list_is_home.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [37c_editor_after_link_replaced_it.png](37c_editor_after_link_replaced_it.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [38_link_edit_list.png](38_link_edit_list.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [10_home.png](10_home.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [11_characters_list.png](11_characters_list.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [12_preview_related_comics.png](12_preview_related_comics.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [13_comic_page.png](13_comic_page.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [14_sign_in_form.png](14_sign_in_form.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [15_favourite_saved.png](15_favourite_saved.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [16_comic_cast.png](16_comic_cast.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [17_cast_member_placeholder.png](17_cast_member_placeholder.png) | `integration_test/comics_journey_test.dart` | downscaled from 1206x2622 |
| [65_sync_sign_in_form.png](65_sync_sign_in_form.png) | `integration_test/settings_signed_in_test.dart` | downscaled from 1206x2622 |
| [66_signed_in_light_synced.png](66_signed_in_light_synced.png) | `integration_test/settings_signed_in_test.dart` | downscaled from 1206x2622 |
| [67_relaunched_still_light.png](67_relaunched_still_light.png) | `integration_test/settings_signed_in_test.dart` | downscaled from 1206x2622 |
