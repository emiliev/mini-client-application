# T-0021-AC3 / AC6: simulator build, launch and deep links

- build `--config=sim //app/mini_client:mini_client_ios`: exit 0 (INFO: Build completed successfully, 1 total action)
- FontManifest has `packages/mc_ds_theme/Inter`: 1; Inter .ttf files bundled: 4
- bundled `assets/app_config.json` env: `dev`
- Info.plist: URL scheme `miniclient`, FlutterDeepLinkingEnabled `true`
- screenshot `ac6-home.png` (original height 2622 px)
- screenshot `ac3-openurl-warm.png` (original height 2622 px)
- screenshot `ac4-openurl-cold.png` (original height 2622 px)
- simulator: `mc-T-0021-engineer-86990` (4EA5F8EA-791A-43B5-9DD3-75FA1A6D81AC), iPhone 17 Pro, iOS 26.2; deleted on exit
- app: mini_client_ios.app, bundle id `com.emiliev.miniclient`
- `simctl launch`: exit 0 (com.emiliev.miniclient: 88514); launchctl entries 10 s later: 1
- `simctl openurl` warm (placeholder/42): exit 0
- `simctl openurl` cold (placeholder/7, app terminated first): exit 0; launchctl entries 10 s later: 0

The screenshots are the visual checkpoints: a reviewer must look at them.
AC3 (openurl screenshots): expected to show the iOS "Open in “Mini Client”?" prompt (F-0020); not decided by this script.

**PASS T-0021-AC6**
