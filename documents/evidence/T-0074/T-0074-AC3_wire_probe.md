# T-0074-AC3: a new list-detail spec, wired by mcgen alone

HEAD `6ccb217b`, copy `/tmp/mc-T-0074-probe-engineer-MWOVqd` (deleted afterwards)

- the copy: 6067 files; the one hand-written addition: `feature/zz_probe/zz_ld_probe/mcgen.yaml`
- PASS: mcgen gen zz_ld_probe
- PASS: mcgen wire
- PASS: mcgen buildgen
  - mcgen buildgen: 13 BUILD file(s), 2 written
- PASS: mcgen gen --check zz_ld_probe (idempotent)
- PASS: mcgen wire --check (idempotent)
- PASS: mcgen buildgen --check (idempotent)

## Files mcgen wrote in the copy

```
app/mini_client/lib/src/wirings.dart
app/mini_client/pubspec.yaml
app/mini_client/wirings.bzl
app/wiring/app_core/lib/src/locations/generated_locations.dart
app/wiring/zz_probe_wiring/.mcgen/wire.json
app/wiring/zz_probe_wiring/BUILD.bazel
app/wiring/zz_probe_wiring/lib/src/di/di_initializer.dart
app/wiring/zz_probe_wiring/lib/src/di/zz_probe_wiring_di_initializer.dart
app/wiring/zz_probe_wiring/lib/src/navigators/zz_ld_probe_navigator_impl.dart
app/wiring/zz_probe_wiring/lib/src/routes/route_targets.dart
app/wiring/zz_probe_wiring/lib/src/routes/route_targets_impl.dart
app/wiring/zz_probe_wiring/lib/src/routes/zz_probe_routes.dart
app/wiring/zz_probe_wiring/lib/zz_probe_wiring.dart
app/wiring/zz_probe_wiring/pubspec.yaml
app/wiring/zz_probe_wiring/test/routes_test.dart
feature/zz_probe/zz_ld_probe/.mcgen/manifest.json
feature/zz_probe/zz_ld_probe/BUILD.bazel
feature/zz_probe/zz_ld_probe/l10n.yaml
feature/zz_probe/zz_ld_probe/lib/src/di/di_initializer.dart
feature/zz_probe/zz_ld_probe/lib/src/di/flow_scope.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/api/zz_ld_probe_api.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/model/comic.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/model/comic_dto.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/model/comic_id.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/model/comic_mapper.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/model/comics_query.dart
feature/zz_probe/zz_ld_probe/lib/src/domain/repository/zz_ld_probe_repository.dart
feature/zz_probe/zz_ld_probe/lib/src/flow/zz_ld_probe_flow.dart
feature/zz_probe/zz_ld_probe/lib/src/flow/zz_ld_probe_flow_state.dart
feature/zz_probe/zz_ld_probe/lib/src/l10n/zz_ld_probe_de.arb
feature/zz_probe/zz_ld_probe/lib/src/l10n/zz_ld_probe_en.arb
feature/zz_probe/zz_ld_probe/lib/src/l10n/zz_ld_probe_en_XA.arb
feature/zz_probe/zz_ld_probe/lib/src/navigator/zz_ld_probe_navigator.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/bloc/comic_preview_bloc.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/bloc/zz_ld_probe_bloc.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/bloc/zz_ld_probe_event.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/bloc/zz_ld_probe_state.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/page/comic_preview_page.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/page/zz_ld_probe_page.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/widget/comic_tile.dart
feature/zz_probe/zz_ld_probe/lib/src/presentation/widget/failure_message.dart
feature/zz_probe/zz_ld_probe/lib/zz_ld_probe.dart
feature/zz_probe/zz_ld_probe/pubspec.yaml
feature/zz_probe/zz_ld_probe/test/architecture/architecture_test.dart
feature/zz_probe/zz_ld_probe/test/contract/comics_api_contract_test.dart
feature/zz_probe/zz_ld_probe/test/feature/step/i_dont_see_the_comic_preview.dart
feature/zz_probe/zz_ld_probe/test/feature/step/i_open_the_comics_list.dart
feature/zz_probe/zz_ld_probe/test/feature/step/i_scroll_the_comics_list_until_i_see.dart
feature/zz_probe/zz_ld_probe/test/feature/step/i_scroll_the_comics_list_until_the_next_page_loads.dart
feature/zz_probe/zz_ld_probe/test/feature/step/i_see_the_comic_preview_for.dart
feature/zz_probe/zz_ld_probe/test/feature/step/i_see_the_first_comics_in_title_order_with_their_bundled_art.dart
feature/zz_probe/zz_ld_probe/test/feature/step/the_app_was_asked_to_open_comic.dart
feature/zz_probe/zz_ld_probe/test/feature/step/the_comics_list_keeps_its_scroll_position.dart
feature/zz_probe/zz_ld_probe/test/feature/step/the_comics_list_shows_comics.dart
feature/zz_probe/zz_ld_probe/test/feature/util/zz_ld_probe_env.dart
feature/zz_probe/zz_ld_probe/test/feature/zz_ld_probe.feature
feature/zz_probe/zz_ld_probe/test/feature/zz_ld_probe_empty.feature
feature/zz_probe/zz_ld_probe/test/flow_scope_test.dart
pubspec.yaml
```

- PASS: bazel build --config=sim //app/mini_client:mini_client_ios
- PASS: bazel test --lockfile_mode=error //...
  - Executed 19 out of 252 tests: 252 tests pass.
  - //feature/zz_probe/zz_ld_probe:bdd_test PASSED
  - //feature/zz_probe/zz_ld_probe:architecture_test PASSED
  - //feature/zz_probe/zz_ld_probe:flow_scope_test PASSED
  - //app/wiring/zz_probe_wiring:routes_test PASSED
  - //app/mini_client:catalogue_test PASSED
  - //app/mini_client:analytics_screens_test PASSED

## //app/mini_client:catalogue_test in the copy

```
  PASS  T-0074-AC3 a link opens the catalogue with home under it, listing every generated flow
  PASS  T-0074-AC3 the catalogue opens zz_ld_probe at its route, and Back returns to the catalogue
  PASS  T-0074-AC3 a catalogue tile pushes its location, and Back returns to the catalogue
```

**PASS T-0074-AC3**
