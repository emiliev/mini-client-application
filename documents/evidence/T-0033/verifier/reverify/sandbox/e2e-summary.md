# E2E summary: T-0033 (verifier)

| Field | Value |
|---|---|
| Result | **FAIL** |
| Task | T-0033 |
| Role | verifier |
| Project | `/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/e2e-sandbox/app/sandbox/universe_sandbox` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0033-verifier-69243` |
| Simulator UDID | `4AF353A3-7009-4289-A5DE-0F0D9689B0F4` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-25T14:25:27Z |
| Finished | 2026-11-25T14:27:40Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/characters_sandbox_test.dart` | PASS | 35 s | [e2e-characters_sandbox_test.log](e2e-characters_sandbox_test.log) |
| `integration_test/verifier_cold_link_test.dart` | PASS | 20 s | [e2e-verifier_cold_link_test.log](e2e-verifier_cold_link_test.log) |
| `integration_test/verifier_foreign_link_test.dart` | FAIL | 56 s | [e2e-verifier_foreign_link_test.log](e2e-verifier_foreign_link_test.log) |

## Screenshots

| File | Target | Note |
|---|---|---|
| [01_sandbox_characters.png](01_sandbox_characters.png) | `integration_test/characters_sandbox_test.dart` | downscaled from 1206x2622 |
| [rv_01_sandbox_cold_link_details_5.png](rv_01_sandbox_cold_link_details_5.png) | `integration_test/verifier_cold_link_test.dart` | downscaled from 1206x2622 |
| [rv_02_sandbox_cold_foreign_link_list.png](rv_02_sandbox_cold_foreign_link_list.png) | `integration_test/verifier_foreign_link_test.dart` | downscaled from 1206x2622 |
