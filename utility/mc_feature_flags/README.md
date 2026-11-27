# mc_feature_flags

Typed feature flags and experiments for the app (T-0052, plan 01 U09). Pure Dart. Design record and gotchas: [F-0052](../../documents/findings/F-0052-feature-flags.md).

## Using it

A feature declares its flags as `const` values in its own package. The kit holds none.

```dart
enum Layout { grid, list }

const searchLayout = FeatureFlag<Layout>(
  key: 'search.layout',
  defaultValue: Layout.grid,
  description: 'The search results layout.',
  codec: EnumFlagCodec<Layout>(Layout.values),
);

const storeHomeLayout = Experiment(
  key: 'store_home_layout',
  variants: [ExperimentVariant('control', 5000), ExperimentVariant('rich', 5000)],
);

final flags = diContainer<FeatureFlagsReader>();
flags.value(searchLayout);          // synchronous
flags.watch(searchLayout);          // the current value, then distinct changes
flags.variant(storeHomeLayout);     // 'control' or 'rich', stable per user
await flags.refresh();              // never throws
```

Codecs: `BoolFlagCodec`, `IntFlagCodec`, `StringFlagCodec`, `EnumFlagCodec`. Keys are unique: registering a second flag with a key that is taken throws `DuplicateFlagKeyError`.

## Evaluation order (pinned by tests)

1. A **local override**, only when `AppConfig.env` is not release-like (`dev`, `e2e`, `perf` and `test` accept overrides; every other name rejects them).
2. The **remote value of the last successful fetch for the current session epoch**.
3. The **last-known-good** remote value from storage, for the same user, while no fetch has succeeded yet in this epoch.
4. The flag's `defaultValue`.

A value of the wrong type, or a source with no value, falls to the next source. When the user changes (a sign-out, or another user) the saved body of the previous user is deleted, so a user's targeted flags do not stay on disk. The wrong type is reported once to `Monitoring`. Unknown remote keys are ignored.

## Experiments

The bucket of a subject is `FNV-1a-32(utf8("<experimentKey>:<subjectId>")) % 10000`. The variants' cumulative weights are scaled to 10000 and the first whose bound is above the bucket wins; a weight of 0 never wins. The subject is the signed-in user id, else a random install id kept in storage. Weights are integers from 0 to `maxVariantWeight` (1,000,000,000: above it the scaled sum could overflow, so a larger remote weight is malformed and reported). Remote config supplies weights per variant name; an entry with no variants, a repeated name, or a bad weight is malformed and the declared weights apply; a local override can force a variant.

## Why these dependencies

Plan 01 lists `mc_prelude`, `mc_di`, `mc_config`, `mc_storage`, `mc_api_client` and `mc_api_errors`. This package adds two:

- `mc_session`: the session epoch and user (and `SessionEpochs.epochChanges`, so a same-user sign-in is seen at once). A fetch is for one epoch, a result for an older epoch is dropped, and the signed-in user is the experiment subject.
- `mc_monitoring`: the one report of a wrong-typed remote value (and failed fetches).

## Boot

`FeatureFlagsDIInitializer` goes after `ApiAuthDIInitializer` in the root list. It reads what is saved (only files that exist), registers `FeatureFlags` (also as `FeatureFlagsReader` and `FeatureFlagOverrides`), and starts the first fetch **without waiting for it**.
