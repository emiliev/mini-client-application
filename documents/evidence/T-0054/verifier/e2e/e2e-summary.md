# E2E summary: T-0054 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0054 |
| Role | verifier |
| Project | `/tmp/mc-T-0054-verifier-e2e/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0054-verifier-95588` |
| Simulator UDID | `424AB238-3792-40DF-B308-C1338F33C0F9` |
| Runner | `/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0054-verifier/run_target.sh {udid} {target} {driver}` |
| Started | 2026-11-27T11:09:45Z |
| Finished | 2026-11-27T11:21:45Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/analytics_screens_test.dart` | PASS | 78 s | [e2e-analytics_screens_test.log](e2e-analytics_screens_test.log) |
| `integration_test/character_details_deeplink_test.dart` | PASS | 40 s | [e2e-character_details_deeplink_test.log](e2e-character_details_deeplink_test.log) |
| `integration_test/characters_deeplink_test.dart` | PASS | 30 s | [e2e-characters_deeplink_test.log](e2e-characters_deeplink_test.log) |
| `integration_test/characters_journey_test.dart` | PASS | 38 s | [e2e-characters_journey_test.log](e2e-characters_journey_test.log) |
| `integration_test/characters_link_after_flow_test.dart` | PASS | 28 s | [e2e-characters_link_after_flow_test.log](e2e-characters_link_after_flow_test.log) |
| `integration_test/comic_deeplink_test.dart` | PASS | 37 s | [e2e-comic_deeplink_test.log](e2e-comic_deeplink_test.log) |
| `integration_test/comics_journey_test.dart` | PASS | 56 s | [e2e-comics_journey_test.log](e2e-comics_journey_test.log) |
| `integration_test/not_found_cold_bad_comic_test.dart` | PASS | 41 s | [e2e-not_found_cold_bad_comic_test.log](e2e-not_found_cold_bad_comic_test.log) |
| `integration_test/not_found_cold_test.dart` | PASS | 38 s | [e2e-not_found_cold_test.log](e2e-not_found_cold_test.log) |
| `integration_test/reading_list_deeplink_test.dart` | PASS | 30 s | [e2e-reading_list_deeplink_test.log](e2e-reading_list_deeplink_test.log) |
| `integration_test/reading_list_journey_test.dart` | PASS | 50 s | [e2e-reading_list_journey_test.log](e2e-reading_list_journey_test.log) |
| `integration_test/search_deeplink_test.dart` | PASS | 38 s | [e2e-search_deeplink_test.log](e2e-search_deeplink_test.log) |
| `integration_test/search_journey_test.dart` | PASS | 41 s | [e2e-search_journey_test.log](e2e-search_journey_test.log) |
| `integration_test/v1_cold_abc_back_test.dart` | PASS | 29 s | [e2e-v1_cold_abc_back_test.log](e2e-v1_cold_abc_back_test.log) |
| `integration_test/v2_cold_frag_gohome_test.dart` | PASS | 31 s | [e2e-v2_cold_frag_gohome_test.log](e2e-v2_cold_frag_gohome_test.log) |
| `integration_test/v3_cold_nope_gohome_test.dart` | PASS | 45 s | [e2e-v3_cold_nope_gohome_test.log](e2e-v3_cold_nope_gohome_test.log) |
| `integration_test/v4_cold_bad_comic_back_test.dart` | PASS | 33 s | [e2e-v4_cold_bad_comic_back_test.log](e2e-v4_cold_bad_comic_back_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [01_home.png](01_home.png) | `integration_test/analytics_screens_test.dart` | downscaled from 1206x2622 |
| [02_characters_list.png](02_characters_list.png) | `integration_test/analytics_screens_test.dart` | downscaled from 1206x2622 |
| [03_back_to_home.png](03_back_to_home.png) | `integration_test/analytics_screens_test.dart` | downscaled from 1206x2622 |
| [55_deep_link_character_details.png](55_deep_link_character_details.png) | `integration_test/character_details_deeplink_test.dart` | downscaled from 1206x2622 |
| [55b_back_from_details_is_list.png](55b_back_from_details_is_list.png) | `integration_test/character_details_deeplink_test.dart` | downscaled from 1206x2622 |
| [55c_back_from_list_is_home.png](55c_back_from_list_is_home.png) | `integration_test/character_details_deeplink_test.dart` | downscaled from 1206x2622 |
| [05_deep_link_characters.png](05_deep_link_characters.png) | `integration_test/characters_deeplink_test.dart` | downscaled from 1206x2622 |
| [05b_back_from_characters_is_home.png](05b_back_from_characters_is_home.png) | `integration_test/characters_deeplink_test.dart` | downscaled from 1206x2622 |
| [characters_journey_test-01_home.png](characters_journey_test-01_home.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [characters_journey_test-02_characters_list.png](characters_journey_test-02_characters_list.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [03_preview.png](03_preview.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [04_full_profile_placeholder.png](04_full_profile_placeholder.png) | `integration_test/characters_journey_test.dart` | downscaled from 1206x2622 |
| [06_link_after_flow.png](06_link_after_flow.png) | `integration_test/characters_link_after_flow_test.dart` | downscaled from 1206x2622 |
| [18_deep_link_comic.png](18_deep_link_comic.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
| [18b_back_from_comic_is_home.png](18b_back_from_comic_is_home.png) | `integration_test/comic_deeplink_test.dart` | downscaled from 1206x2622 |
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
| [62_cold_bad_comic_not_found.png](62_cold_bad_comic_not_found.png) | `integration_test/not_found_cold_bad_comic_test.dart` | downscaled from 1206x2622 |
| [62b_cold_bad_comic_go_home.png](62b_cold_bad_comic_go_home.png) | `integration_test/not_found_cold_bad_comic_test.dart` | downscaled from 1206x2622 |
| [60_cold_nope_not_found.png](60_cold_nope_not_found.png) | `integration_test/not_found_cold_test.dart` | downscaled from 1206x2622 |
| [60b_cold_nope_back_is_home.png](60b_cold_nope_back_is_home.png) | `integration_test/not_found_cold_test.dart` | downscaled from 1206x2622 |
| [61_running_bad_comic_not_found.png](61_running_bad_comic_not_found.png) | `integration_test/not_found_cold_test.dart` | downscaled from 1206x2622 |
| [61b_running_go_home.png](61b_running_go_home.png) | `integration_test/not_found_cold_test.dart` | downscaled from 1206x2622 |
| [37_deep_link_new_list.png](37_deep_link_new_list.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [37b_back_from_new_list_is_home.png](37b_back_from_new_list_is_home.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [37c_editor_after_link_replaced_it.png](37c_editor_after_link_replaced_it.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [38_link_edit_list.png](38_link_edit_list.png) | `integration_test/reading_list_deeplink_test.dart` | downscaled from 1206x2622 |
| [30_home_new_reading_list.png](30_home_new_reading_list.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [31_sign_in_sheet.png](31_sign_in_sheet.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [32_step1_blocked.png](32_step1_blocked.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [33_step1_details.png](33_step1_details.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [34_step2_comics.png](34_step2_comics.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [35_step3_review.png](35_step3_review.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [36_home_list_created.png](36_home_list_created.png) | `integration_test/reading_list_journey_test.dart` | downscaled from 1206x2622 |
| [36_deep_link_search.png](36_deep_link_search.png) | `integration_test/search_deeplink_test.dart` | downscaled from 1206x2622 |
| [36b_back_from_search_is_home.png](36b_back_from_search_is_home.png) | `integration_test/search_deeplink_test.dart` | downscaled from 1206x2622 |
| [37_link_to_running_app_search.png](37_link_to_running_app_search.png) | `integration_test/search_deeplink_test.dart` | downscaled from 1206x2622 |
| [30_home_search_entry.png](30_home_search_entry.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [31_search_opened.png](31_search_opened.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [32_search_results_grouped.png](32_search_results_grouped.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [33_search_comics_chip.png](33_search_comics_chip.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [34_comic_from_search.png](34_comic_from_search.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [35_recent_searches.png](35_recent_searches.png) | `integration_test/search_journey_test.dart` | downscaled from 1206x2622 |
| [v1_cold_abc_back_a_cold.png](v1_cold_abc_back_a_cold.png) | `integration_test/v1_cold_abc_back_test.dart` | downscaled from 1206x2622 |
| [v1_cold_abc_back_b_home.png](v1_cold_abc_back_b_home.png) | `integration_test/v1_cold_abc_back_test.dart` | downscaled from 1206x2622 |
| [v1_cold_abc_back_c_running_nope.png](v1_cold_abc_back_c_running_nope.png) | `integration_test/v1_cold_abc_back_test.dart` | downscaled from 1206x2622 |
| [v1_cold_abc_back_d_home.png](v1_cold_abc_back_d_home.png) | `integration_test/v1_cold_abc_back_test.dart` | downscaled from 1206x2622 |
| [v2_cold_frag_gohome_a_cold.png](v2_cold_frag_gohome_a_cold.png) | `integration_test/v2_cold_frag_gohome_test.dart` | downscaled from 1206x2622 |
| [v2_cold_frag_gohome_b_home.png](v2_cold_frag_gohome_b_home.png) | `integration_test/v2_cold_frag_gohome_test.dart` | downscaled from 1206x2622 |
| [v2_cold_frag_gohome_c_running_nope.png](v2_cold_frag_gohome_c_running_nope.png) | `integration_test/v2_cold_frag_gohome_test.dart` | downscaled from 1206x2622 |
| [v2_cold_frag_gohome_d_home.png](v2_cold_frag_gohome_d_home.png) | `integration_test/v2_cold_frag_gohome_test.dart` | downscaled from 1206x2622 |
| [v3_cold_nope_gohome_a_cold.png](v3_cold_nope_gohome_a_cold.png) | `integration_test/v3_cold_nope_gohome_test.dart` | downscaled from 1206x2622 |
| [v3_cold_nope_gohome_b_home.png](v3_cold_nope_gohome_b_home.png) | `integration_test/v3_cold_nope_gohome_test.dart` | downscaled from 1206x2622 |
| [v3_cold_nope_gohome_c_running_nope.png](v3_cold_nope_gohome_c_running_nope.png) | `integration_test/v3_cold_nope_gohome_test.dart` | downscaled from 1206x2622 |
| [v3_cold_nope_gohome_d_home.png](v3_cold_nope_gohome_d_home.png) | `integration_test/v3_cold_nope_gohome_test.dart` | downscaled from 1206x2622 |
| [v4_cold_bad_comic_back_a_cold.png](v4_cold_bad_comic_back_a_cold.png) | `integration_test/v4_cold_bad_comic_back_test.dart` | downscaled from 1206x2622 |
| [v4_cold_bad_comic_back_b_home.png](v4_cold_bad_comic_back_b_home.png) | `integration_test/v4_cold_bad_comic_back_test.dart` | downscaled from 1206x2622 |
| [v4_cold_bad_comic_back_c_running_nope.png](v4_cold_bad_comic_back_c_running_nope.png) | `integration_test/v4_cold_bad_comic_back_test.dart` | downscaled from 1206x2622 |
| [v4_cold_bad_comic_back_d_home.png](v4_cold_bad_comic_back_d_home.png) | `integration_test/v4_cold_bad_comic_back_test.dart` | downscaled from 1206x2622 |
