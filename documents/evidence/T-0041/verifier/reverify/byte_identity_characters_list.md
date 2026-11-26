# T-0032-AC6: characters_list codegen vs build_runner

Overlay inputs: `//feature/characters/characters_list:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/characters/characters_list
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/characters_list
   17 files from //feature/characters/characters_list:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 14s; wrote 10 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/characters/characters_list/lib/src/domain/api/characters_list_api.g.dart  sha256 70f477ed1d71cab0
EQUAL   feature/characters/characters_list/lib/src/domain/model/character.freezed.dart  sha256 df12820ec377eab6
EQUAL   feature/characters/characters_list/lib/src/domain/model/character_dto.freezed.dart  sha256 2b86bb8db03bce6e
EQUAL   feature/characters/characters_list/lib/src/domain/model/character_dto.g.dart  sha256 e6a614d01dacaa71
EQUAL   feature/characters/characters_list/lib/src/domain/model/related_comic.freezed.dart  sha256 da19739e2da97880
EQUAL   feature/characters/characters_list/lib/src/flow/characters_list_flow_state.freezed.dart  sha256 a1375d3d268cdaf9
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/characters_list_bloc.freezed.dart  sha256 109d9e05941b95f2
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/related_comics_bloc.freezed.dart  sha256 80efbaa7af8c88f0
== 1. Bazel injectable codegen for //feature/characters/characters_list
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/characters_list_injectable
   18 files from //feature/characters/characters_list:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 11s; wrote 6 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/characters/characters_list/lib/src/di/di_initializer.config.dart  sha256 fa10e9f9b47b0ea8
EQUAL   feature/characters/characters_list/lib/src/domain/api/characters_list_api.injectable.json (shard)  sha256 1d367020be76e321
EQUAL   feature/characters/characters_list/lib/src/domain/repository/characters_list_repository.injectable.json (shard)  sha256 605a4035dd0cb076
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/character_preview_bloc.injectable.json (shard)  sha256 b0c8e6b18ad86491
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/characters_list_bloc.injectable.json (shard)  sha256 5a1e4bb9319fafe1
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/related_comics_bloc.injectable.json (shard)  sha256 886abcddcf60aaed
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 14 of 14 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0032-AC6-byte-identity**
