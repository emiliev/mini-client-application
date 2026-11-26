# E2E summary: T-0033 (verifier)

| Field | Value |
|---|---|
| Result | **PASS** |
| Task | T-0033 |
| Role | verifier |
| Project | `/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/verifier-T0033-r3/sandbox/app/sandbox/universe_sandbox` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0033-verifier-25721` |
| Simulator UDID | `D15C73EC-6ED9-428B-9CA1-295953C5A5EF` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-25T19:37:00Z |
| Finished | 2026-11-25T19:39:42Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/characters_sandbox_link_after_flow_test.dart` | PASS | 31 s | [e2e-characters_sandbox_link_after_flow_test.log](e2e-characters_sandbox_link_after_flow_test.log) |
| `integration_test/characters_sandbox_link_test.dart` | PASS | 18 s | [e2e-characters_sandbox_link_test.log](e2e-characters_sandbox_link_test.log) |
| `integration_test/characters_sandbox_test.dart` | PASS | 23 s | [e2e-characters_sandbox_test.log](e2e-characters_sandbox_test.log) |
| `integration_test/verifier_cold_link_test.dart` | PASS | 22 s | [e2e-verifier_cold_link_test.log](e2e-verifier_cold_link_test.log) |
| `integration_test/verifier_foreign_link_test.dart` | PASS | 26 s | [e2e-verifier_foreign_link_test.log](e2e-verifier_foreign_link_test.log) |
| `integration_test/verifier_warm_own_link_test.dart` | PASS | 26 s | [e2e-verifier_warm_own_link_test.log](e2e-verifier_warm_own_link_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [03_sandbox_link_after_flow.png](03_sandbox_link_after_flow.png) | `integration_test/characters_sandbox_link_after_flow_test.dart` | downscaled from 1206x2622 |
| [02_sandbox_start_link.png](02_sandbox_start_link.png) | `integration_test/characters_sandbox_link_test.dart` | downscaled from 1206x2622 |
| [01_sandbox_characters.png](01_sandbox_characters.png) | `integration_test/characters_sandbox_test.dart` | downscaled from 1206x2622 |
| [rv_01_sandbox_cold_link_details_5.png](rv_01_sandbox_cold_link_details_5.png) | `integration_test/verifier_cold_link_test.dart` | downscaled from 1206x2622 |
| [rv_02_sandbox_cold_foreign_link_list.png](rv_02_sandbox_cold_foreign_link_list.png) | `integration_test/verifier_foreign_link_test.dart` | downscaled from 1206x2622 |
| [rv_03_sandbox_warm_own_link_details_6.png](rv_03_sandbox_warm_own_link_details_6.png) | `integration_test/verifier_foreign_link_test.dart` | downscaled from 1206x2622 |
| [rv_04_sandbox_warm_probe.png](rv_04_sandbox_warm_probe.png) | `integration_test/verifier_warm_own_link_test.dart` | downscaled from 1206x2622 |
