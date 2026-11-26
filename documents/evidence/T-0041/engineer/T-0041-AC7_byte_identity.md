# T-0041-AC7: comics_details codegen vs build_runner

Overlay inputs: `//feature/comics/comics_details:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/comics/comics_details
INFO: Build completed successfully, 69 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/comics_details
   17 files from //feature/comics/comics_details:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 15s; wrote 9 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/comics/comics_details/lib/src/domain/api/comics_details_api.g.dart  sha256 07c324a592cbbbf4
EQUAL   feature/comics/comics_details/lib/src/domain/model/comic.freezed.dart  sha256 e3de81aba3a5a531
EQUAL   feature/comics/comics_details/lib/src/domain/model/comic_dto.freezed.dart  sha256 daeeb2731714dd31
EQUAL   feature/comics/comics_details/lib/src/domain/model/comic_dto.g.dart  sha256 2aa8a7ab2b1abfc4
EQUAL   feature/comics/comics_details/lib/src/flow/comics_details_flow_state.freezed.dart  sha256 a0c1d46a82fe4051
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_details_bloc.freezed.dart  sha256 256d1d90025d9b07
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.freezed.dart  sha256 f93bfc2d9d5ba2b7
== 1. Bazel injectable codegen for //feature/comics/comics_details
INFO: Build completed successfully, 2 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/comics_details_injectable
   18 files from //feature/comics/comics_details:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 5 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/comics/comics_details/lib/src/di/di_initializer.config.dart  sha256 0bf8dd209ab5fafa
EQUAL   feature/comics/comics_details/lib/src/domain/api/comics_details_api.injectable.json (shard)  sha256 1227d3eae0815f1e
EQUAL   feature/comics/comics_details/lib/src/domain/repository/comics_details_repository.injectable.json (shard)  sha256 1b23b3f9c8b9eb07
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_details_bloc.injectable.json (shard)  sha256 440ca26df7e877b4
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.injectable.json (shard)  sha256 f802d518ea2ae176
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 12 of 12 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0041-AC7-byte-identity**
