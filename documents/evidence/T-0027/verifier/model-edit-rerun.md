# Verifier: rerun scope of a model edit (supplement to T-0027-AC2)

Edit: added `@Default(0) int comics,` to `CharacterDto` (`spike/retrofit_api/lib/src/character_dto.dart`), then reverted it.
Both builds ran `tool/bazelw --output_base=/tmp/mc-ob-T-0027-verifier test --remote_download_all --disk_cache= --execution_log_json_file=… //spike/retrofit_api/... //spike/api_envelope/...` with **identical flags** (F-0026 §6). Both exited 0.

Spawns in the execution log after the edit: 19, all `cacheHit=False`. Local action-cache hits aren't logged.

```
DartAnalyze          //spike/retrofit_api:characters_api_test
DartAnalyze          //spike/retrofit_api:retrofit_api
DartAnalyzerSummary  //spike/retrofit_api:_stage_frz
DartAnalyzerSummary  //spike/retrofit_api:retrofit_api            x2
DartCodegen          //spike/retrofit_api:_character_dto_freezed   x2   character_dto.freezed.dart
DartCodegen          //spike/retrofit_api:_character_dto_json_part x2   character_dto.json_serializable.g.part
DartCodegen          //spike/retrofit_api:_character_dto_g         x2   character_dto.g.dart
DartCodegen          //spike/retrofit_api:_characters_api_retrofit_part x2  (dependent through _stage_frz)
DartFormat           //spike/retrofit_api:_stage_frz
DartFormat           //spike/retrofit_api:retrofit_api
DartKernel           //spike/retrofit_api:characters_api_test
DartKernel           //spike/retrofit_api:retrofit_api
DartKernelLink       //spike/retrofit_api:characters_api_test
TestRunner           //spike/retrofit_api:characters_api_test
```

- The model's whole cascade reruns: freezed, then json, then combine. So does its dependent, the retrofit shard of the API file.
- `_characters_api_g` (the API combine) does **not** rerun. The retrofit shard came out byte-identical (the client only calls `fromJson`/`toJson` by name), so the combine cuts off early.
- `//spike/api_envelope` ran no spawns.
