# T-0034 negative controls (engineer)

- AC1: `McFlowContext.di` switched back to `FlowScope.of(this)` -> `flow_kit_test` FAILS 3 of 7 (AC1 x2 and AC2 provide). Restored.
- AC3: `mc_paging` barrel without `$PagedStateCopyWith` -> `copywith_barrel_test` fails to compile: `Type '$PagedStateCopyWith' not found` (holder_state.freezed.dart:252 and :276). Restored.
- AC4: `T-0034-AC4_negative_control_old_exemplar.md` (old `@GET('/v1/characters')` -> FAIL); each run also plants `@GET('/x')`; the `mc_api_client` control test pins Dio's host/path fusion without the slash.
- AC5: `T-0034-AC5_negative_control_old_exemplar.md` (origin/main's exemplar -> FAIL with 13 hits); each run also plants a marker.
