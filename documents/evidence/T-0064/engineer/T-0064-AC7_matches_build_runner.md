# T-0064-AC7: trivia_quiz codegen vs build_runner

Overlay inputs: `//feature/trivia/trivia_quiz:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/trivia/trivia_quiz
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/trivia_quiz
   24 files from //feature/trivia/trivia_quiz:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 10 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/trivia/trivia_quiz/lib/src/domain/api/trivia_quiz_api.g.dart  sha256 18a50d54540db454
EQUAL   feature/trivia/trivia_quiz/lib/src/domain/model/trivia.freezed.dart  sha256 bc8b9d99adcbc3f1
EQUAL   feature/trivia/trivia_quiz/lib/src/domain/model/trivia_dto.freezed.dart  sha256 e37ea0388a16905b
EQUAL   feature/trivia/trivia_quiz/lib/src/domain/model/trivia_dto.g.dart  sha256 eca091312db9a9af
EQUAL   feature/trivia/trivia_quiz/lib/src/flow/trivia_quiz_flow_state.freezed.dart  sha256 ddc41658ad681e00
EQUAL   feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_play_bloc.freezed.dart  sha256 640ff6c7717e6aa2
EQUAL   feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_results_bloc.freezed.dart  sha256 4d668c0c7f22a73f
EQUAL   feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_setup_bloc.freezed.dart  sha256 4171f02bcd7f9a8b
== 1. Bazel injectable codegen for //feature/trivia/trivia_quiz
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/trivia_quiz_injectable
   25 files from //feature/trivia/trivia_quiz:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 11s; wrote 6 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/trivia/trivia_quiz/lib/src/di/di_initializer.config.dart  sha256 d0b93a5c7a5e711c
EQUAL   feature/trivia/trivia_quiz/lib/src/domain/api/trivia_quiz_api.injectable.json (shard)  sha256 892ed45a9eaa3784
EQUAL   feature/trivia/trivia_quiz/lib/src/domain/repository/trivia_quiz_repository.injectable.json (shard)  sha256 a149aa69efe57079
EQUAL   feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_play_bloc.injectable.json (shard)  sha256 66098abb38397d48
EQUAL   feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_results_bloc.injectable.json (shard)  sha256 6d963ca86ecbcab4
EQUAL   feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_setup_bloc.injectable.json (shard)  sha256 59403f47c991dde6
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 0 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 14 of 14 |
| expected but not EQUAL | none |
| EQUAL but not on the list | none |

**PASS T-0064-AC7-byte-identity**
