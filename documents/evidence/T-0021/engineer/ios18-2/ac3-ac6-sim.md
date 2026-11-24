# T-0021-AC3 / AC6: simulator build, launch and deep links

- build `--config=sim //app/mini_client:mini_client_ios`: exit 0 (INFO: Build completed successfully, 1 total action)
- FontManifest has `packages/mc_ds_theme/Inter`: 1; Inter .ttf files bundled: 4
- bundled `assets/app_config.json` env: `dev`
- Info.plist: URL scheme `miniclient`, FlutterDeepLinkingEnabled `true`
- screenshot `ac6-home.png` (original height 1334 px)
- screenshot `ac3-e2e-link.png` (original height 1334 px)
- e2e start link written: 1; relaunch exit 0; file consumed by the app: 1
- screenshot `ac3-openurl-warm.png` (original height 1334 px)
- screenshot `ac4-openurl-cold.png` (original height 1334 px)
- simulator: `mc-T-0021-engineer-iOS-18-2-359` (E188F943-85B5-4AFE-BC33-8307921ADC75), iPhone SE (3rd generation), `com.apple.CoreSimulator.SimRuntime.iOS-18-2`; deleted on exit
- app: mini_client_ios.app, bundle id `com.emiliev.miniclient`
- `simctl launch`: exit 0 (com.emiliev.miniclient: 1172); launchctl entries 10 s later: 1
- `simctl openurl` warm (placeholder/42): exit 0
- `simctl openurl` cold (placeholder/7, app terminated first): exit 0; launchctl entries 10 s later: 0

The screenshots are the visual checkpoints: a reviewer must look at them.
AC3: `ac3-e2e-link.png` must show *Placeholder detail 42*. The openurl screenshots are expected to show the iOS "Open in “Mini Client”?" prompt (F-0020, P-042).

**PASS T-0021-AC6 + AC3 (e2e link)**
