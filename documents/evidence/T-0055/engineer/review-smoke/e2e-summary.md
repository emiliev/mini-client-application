# E2E summary: T-0055 (engineer)

| Field | Value |
|---|---|
| Result | **FAIL** |
| Task | T-0055 |
| Role | engineer |
| Project | `/tmp/mc-T-0055-engineer-smoke/app/mini_client` |
| Device | iPhone 17 Pro (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`) |
| Runtime | iOS 26.2 (`com.apple.CoreSimulator.SimRuntime.iOS-26-2`) |
| Simulator | `mc-T-0055-engineer-40947` |
| Simulator UDID | `2AD449A4-F957-419A-8130-39950B1E9765` |
| Runner | `fvm flutter drive --driver={driver} --target={target} -d {udid}` |
| Started | 2026-11-27T10:23:02Z |
| Finished | 2026-11-27T10:24:15Z |

## Targets

| Target | Result | Duration | Log |
|---|---|---|---|
| `integration_test/zz_good_test.dart` | PASS | 41 s | [e2e-zz_good_test.log](e2e-zz_good_test.log) |
| `integration_test/zz_broken_test.dart` | FAIL (build failed: BUILD FAILED) | 12 s | [e2e-zz_broken_test.log](e2e-zz_broken_test.log) |

## Screenshots

_None._
