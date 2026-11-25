# Upstream drafts

_Index owned by the Tech Lead (R25)._ One folder per draft: `U-D-*` is a PR draft that matches exactly one patch in `third_party/rules_patches/`, and `U-X-*` is an issue against another project. Nothing is filed until the PO grants GitHub access ([Q-013](../open-questions.md#q-013)).

| Draft | Target | Patch | Status | Source |
|---|---|---|---|---|
| [U-D-retrofit](U-D-retrofit/README.md) | Mivr/ai_rules_dart: `retrofit_generator` shim + `retrofit_library` | `ai_rules_dart/0001` | Draft; repro passes uncached | T-0027 |
| [U-D-injectable](U-D-injectable/README.md) | Mivr/ai_rules_dart: injectable two-stage shim (shards + aggregate), vendored generator | `ai_rules_dart/0002` | Draft | T-0028 |
| [U-X-injectable-lean_builder](U-X-injectable-lean_builder/README.md) | injectable_generator: make lean_builder optional (it forces analyzer 14.1.0) | none | Draft issue | T-0028 |
| [U-D-bdd](U-D-bdd/README.md) | Mivr/ai_rules_dart: BDD generator (`.feature` → `flutter_test`) with step indexes | `ai_rules_dart/0003` | Draft | T-0029 |
| [U-X-flow_builder-navigation-channel](U-X-flow_builder-navigation-channel/README.md) | felangel/flow_builder: the channel handler drops `pushRouteInformation` and is never restored | `third_party/flow_builder` (vendored, 3 hunks) | Draft issue | T-0035 |
