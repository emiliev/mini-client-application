# T-0048-AC7: library_reading_list_editor codegen vs build_runner

Overlay inputs: `//feature/library/library_reading_list_editor:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/library/library_reading_list_editor
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/library_reading_list_editor
   17 files from //feature/library/library_reading_list_editor:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 16s; wrote 9 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/library/library_reading_list_editor/lib/src/domain/api/reading_list_editor_api.g.dart  sha256 68fafa773c30936f
EQUAL   feature/library/library_reading_list_editor/lib/src/domain/model/reading_list.freezed.dart  sha256 1e817bc86b991da5
EQUAL   feature/library/library_reading_list_editor/lib/src/domain/model/reading_list_dto.freezed.dart  sha256 26b9b8265860aca9
EQUAL   feature/library/library_reading_list_editor/lib/src/domain/model/reading_list_dto.g.dart  sha256 0f13460a673b9be6
EQUAL   feature/library/library_reading_list_editor/lib/src/flow/reading_list_editor_flow_state.freezed.dart  sha256 b3b4713cf1949b31
EQUAL   feature/library/library_reading_list_editor/lib/src/presentation/bloc/comic_picker_bloc.freezed.dart  sha256 8083189a2865e406
EQUAL   feature/library/library_reading_list_editor/lib/src/presentation/bloc/reading_list_editor_bloc.freezed.dart  sha256 056834ae3887378f
== 1. Bazel injectable codegen for //feature/library/library_reading_list_editor
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/library_reading_list_editor_injectable
   18 files from //feature/library/library_reading_list_editor:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 5 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/library/library_reading_list_editor/lib/src/di/di_initializer.config.dart  sha256 f09bd3e34954fe59
EQUAL   feature/library/library_reading_list_editor/lib/src/domain/api/reading_list_editor_api.injectable.json (shard)  sha256 20405803f0e5ce26
EQUAL   feature/library/library_reading_list_editor/lib/src/domain/repository/reading_list_editor_repository.injectable.json (shard)  sha256 81eb4ffcbb9c21ae
EQUAL   feature/library/library_reading_list_editor/lib/src/presentation/bloc/comic_picker_bloc.injectable.json (shard)  sha256 15b36a12f01ad493
EQUAL   feature/library/library_reading_list_editor/lib/src/presentation/bloc/reading_list_editor_bloc.injectable.json (shard)  sha256 8c2f39893da2e9d6
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 12 of 12 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0048-AC7-byte-identity**
