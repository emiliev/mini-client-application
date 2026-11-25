# Vendored: flow_builder 0.1.0

| | |
|---|---|
| Upstream | https://github.com/felangel/flow_builder, pub.dev package `flow_builder` |
| Version | 0.1.0 |
| Archive | `https://pub.dev/api/archives/flow_builder-0.1.0.tar.gz` |
| Archive sha256 | `9e66aa7209e9a31c347bb316abf191d2300db41cd6b7254f89abd4e76d9b3f8d` (the hash `pubspec.lock` held for the hosted copy) |
| Task | T-0035 (Deep links survive a mounted `FeatureFlow`); finding F-0034 |
| Licence | MIT, `LICENSE` is byte-identical to the archive |
| Upstream draft | `documents/upstream/U-X-flow_builder-navigation-channel/README.md` |

## Why
flow_builder 0.1.0 replaces Flutter's `flutter/navigation` method-call handler
(`SystemChannels.navigation.setMethodCallHandler`) the first time a `FlowBuilder`
mounts, and never puts the framework's handler back. Its replacement knows only
`popRoute` and `pushRoute`; the engine's deep links arrive as `pushRouteInformation`,
which it answers with `null` and drops. Once any flow is on screen, deep links do
nothing. Fixed here, at the kit level, so no feature can trip over it.

## What differs from the archive
`lib/` equals the archive except for the diff in
[`0001-forward-pushRouteInformation.patch`](0001-forward-pushRouteInformation.patch)
(`diff -u` of `lib/flow_builder.dart`; the other files of `lib/` are unchanged):

1. `_handleSystemNavigation` handles `pushRouteInformation` by passing its
   `location` to `WidgetsBinding.instance.handlePushRoute`, which is what the
   framework's handler does for it (it notifies `didPushRouteInformation`).
2. An unknown method returns `false` (the framework's answer), not `null`.

Not carried over from the archive: `example/`, `test/`, `art/`, `README.md`,
`coverage_badge.svg`, the upstream `analysis_options.yaml` (it includes
`very_good_analysis`). `CHANGELOG.md` is kept as is.

Also changed, outside `lib/`:
- `pubspec.yaml`: `publish_to: none`, `resolution: workspace`, `sdk: ^3.13.0`
  (workspace rule), no `dev_dependencies`, no `flutter:` SDK constraint.
- `analysis_options.yaml` and `BUILD.bazel` are new (Bazel `flutter_library`;
  the workspace lint rules do not apply to vendored code).

## Known limits of the fix
- The framework's handler is private (`WidgetsBinding._handleNavigationInvocation`)
  and the engine keeps no getter for a registered handler, so it cannot be captured
  and restored. flow_builder's handler therefore stays installed after the last flow
  is disposed and now forwards every method to the same `WidgetsBinding` entry points
  as the framework's handler, so the channel behaves as without a flow.
- The `state` of a `pushRouteInformation` message is dropped: `handlePushRoute` takes a
  location only. iOS sends none. If a platform starts sending state, replace this with
  a real observer fan-out.
- `popRoute` is unchanged: flow_builder's interceptors still run before the framework.
  Android back handling is out of scope (Q-009).

## Checking the provenance
`tool/checks/T-0035-AC4_provenance.sh` downloads the archive, verifies the sha256, and
fails unless `lib/` differs from it by exactly the patch above and `LICENSE` is equal.

## Updating
Re-vendor from the new archive, re-apply the patch, run the check. Drop the vendored
copy when upstream forwards the unknown methods (see the upstream draft).
