# T-0046-AC7: discovery_search codegen vs build_runner

Overlay inputs: `//feature/discovery/discovery_search:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/discovery/discovery_search
INFO: Build completed successfully, 2816 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/discovery_search
   14 files from //feature/discovery/discovery_search:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 8 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/discovery/discovery_search/lib/src/domain/api/discovery_search_api.g.dart  sha256 53cf3413ed74dd85
EQUAL   feature/discovery/discovery_search/lib/src/domain/model/search_dto.freezed.dart  sha256 328a661a7843abbe
EQUAL   feature/discovery/discovery_search/lib/src/domain/model/search_dto.g.dart  sha256 d45b3e09f16dfca3
EQUAL   feature/discovery/discovery_search/lib/src/domain/model/search_results.freezed.dart  sha256 b76ae52cd65fdf80
EQUAL   feature/discovery/discovery_search/lib/src/flow/discovery_search_flow_state.freezed.dart  sha256 dfe85fc5959ebca2
EQUAL   feature/discovery/discovery_search/lib/src/presentation/bloc/discovery_search_bloc.freezed.dart  sha256 e155fe080c2f9b32
== 1. Bazel injectable codegen for //feature/discovery/discovery_search
INFO: Build completed successfully, 99 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/discovery_search_injectable
   15 files from //feature/discovery/discovery_search:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 11s; wrote 5 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/discovery/discovery_search/lib/src/di/di_initializer.config.dart  sha256 3409b2475d4f96a0
EQUAL   feature/discovery/discovery_search/lib/src/di/di_module.injectable.json (shard)  sha256 bf3880186ed19271
EQUAL   feature/discovery/discovery_search/lib/src/domain/api/discovery_search_api.injectable.json (shard)  sha256 1a8a40079143ceaf
EQUAL   feature/discovery/discovery_search/lib/src/domain/repository/discovery_search_repository.injectable.json (shard)  sha256 afacab9beb8459f7
EQUAL   feature/discovery/discovery_search/lib/src/presentation/bloc/discovery_search_bloc.injectable.json (shard)  sha256 f631c4b5a5ee1367
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 11 of 11 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0046-AC7-byte-identity**
