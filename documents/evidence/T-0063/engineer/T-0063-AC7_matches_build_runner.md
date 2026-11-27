# T-0063-AC7: settings_appearance codegen vs build_runner

Overlay inputs: `//feature/settings/settings_appearance:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/settings/settings_appearance
INFO: Build completed successfully, 63 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/settings_appearance
   7 files from //feature/settings/settings_appearance:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 14s; wrote 2 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/settings/settings_appearance/lib/src/flow/settings_appearance_flow_state.freezed.dart  sha256 310df23518f5c0c3
EQUAL   feature/settings/settings_appearance/lib/src/presentation/bloc/appearance_bloc.freezed.dart  sha256 18fc4851505c3668
== 1. Bazel injectable codegen for //feature/settings/settings_appearance
INFO: Build completed successfully, 2 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/settings_appearance_injectable
   8 files from //feature/settings/settings_appearance:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 12s; wrote 2 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/settings/settings_appearance/lib/src/di/di_initializer.config.dart  sha256 6ced70dd680f0d8e
EQUAL   feature/settings/settings_appearance/lib/src/presentation/bloc/appearance_bloc.injectable.json (shard)  sha256 61e7d72a8605a2e8
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 4 of 4 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0063-AC7-byte-identity**
