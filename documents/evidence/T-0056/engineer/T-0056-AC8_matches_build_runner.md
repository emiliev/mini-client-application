# T-0056-AC8: store_home codegen vs build_runner

Overlay inputs: `//feature/store/store_home:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/store/store_home
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/store_home
   33 files from //feature/store/store_home:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 15s; wrote 13 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/store/store_home/lib/src/domain/api/store_home_api.g.dart  sha256 ef942a77d8c02777
EQUAL   feature/store/store_home/lib/src/domain/model/store.freezed.dart  sha256 e145a02da45f7b63
EQUAL   feature/store/store_home/lib/src/domain/model/store_dto.freezed.dart  sha256 317e7223565fbfce
EQUAL   feature/store/store_home/lib/src/domain/model/store_dto.g.dart  sha256 d3afed1eb519540e
EQUAL   feature/store/store_home/lib/src/flow/store_home_flow_state.freezed.dart  sha256 ebea43e114678816
EQUAL   feature/store/store_home/lib/src/presentation/bloc/banners_bloc.freezed.dart  sha256 1c738bb6150a0c5e
EQUAL   feature/store/store_home/lib/src/presentation/bloc/cart_summary_bloc.freezed.dart  sha256 8b2fb2006fd86b45
EQUAL   feature/store/store_home/lib/src/presentation/bloc/categories_bloc.freezed.dart  sha256 ad5584f3244a4f22
EQUAL   feature/store/store_home/lib/src/presentation/bloc/category_products_bloc.freezed.dart  sha256 442a58e1f922c2f1
EQUAL   feature/store/store_home/lib/src/presentation/bloc/deals_bloc.freezed.dart  sha256 a242559751cbea6a
EQUAL   feature/store/store_home/lib/src/presentation/bloc/featured_bloc.freezed.dart  sha256 c4a8e297a0f4a6da
== 1. Bazel injectable codegen for //feature/store/store_home
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/store_home_injectable
   34 files from //feature/store/store_home:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 9 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/store/store_home/lib/src/di/di_initializer.config.dart  sha256 92c89703d9ad74d0
EQUAL   feature/store/store_home/lib/src/domain/api/store_home_api.injectable.json (shard)  sha256 21667e246ae74b7e
EQUAL   feature/store/store_home/lib/src/domain/repository/store_home_repository.injectable.json (shard)  sha256 09b14db93fdde03d
EQUAL   feature/store/store_home/lib/src/presentation/bloc/banners_bloc.injectable.json (shard)  sha256 321183835810ff02
EQUAL   feature/store/store_home/lib/src/presentation/bloc/cart_summary_bloc.injectable.json (shard)  sha256 411cac3ca044cace
EQUAL   feature/store/store_home/lib/src/presentation/bloc/categories_bloc.injectable.json (shard)  sha256 8948b81e56d14535
EQUAL   feature/store/store_home/lib/src/presentation/bloc/category_products_bloc.injectable.json (shard)  sha256 feea7904e338db67
EQUAL   feature/store/store_home/lib/src/presentation/bloc/deals_bloc.injectable.json (shard)  sha256 9e94b0c22e12810b
EQUAL   feature/store/store_home/lib/src/presentation/bloc/featured_bloc.injectable.json (shard)  sha256 0a21c4af0e52e3b1
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 20 of 20 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0056-AC8-byte-identity**
