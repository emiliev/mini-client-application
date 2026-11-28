# T-0074-AC3: a new list-detail spec, wired by mcgen alone

HEAD `8c04ea2e`, copy `/tmp/mc-T-0074-probe-engineer-k36b1W` (deleted afterwards)

- the copy: 6116 files; the one hand-written addition: `feature/zz_probe/zz_ld_probe/mcgen.yaml`
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
- **FAIL**: bazel test --lockfile_mode=error //...
```
//app/mini_client:app_test                                            NO STATUS
//app/mini_client:bdd_test                                            NO STATUS
//app/mini_client:catalogue_test                                      NO STATUS
//app/mini_client:characters_search_route_test                        NO STATUS
//app/mini_client:comic_route_test                                    NO STATUS
//app/mini_client:deep_link_back_stack_test                           NO STATUS
//app/mini_client:links_after_flow_test                               NO STATUS
//app/mini_client:not_found_test                                      NO STATUS
//app/mini_client:reading_list_route_test                             NO STATUS
//app/mini_client:search_route_test                                   NO STATUS
//app/mini_client:settings_route_test                                 NO STATUS
//app/mini_client:sign_in_guard_app_test                              NO STATUS
//app/mini_client:store_route_test                                    NO STATUS
//app/mini_client:trivia_route_test                                   NO STATUS
//app/sandbox/universe_sandbox:universe_sandbox_links_test            NO STATUS
//app/sandbox/universe_sandbox:universe_sandbox_router_test           NO STATUS
//app/wiring/account_wiring:routes_test                               NO STATUS
//app/wiring/chronicle_wiring:routes_test                             NO STATUS
//app/wiring/universe_wiring:routes_test                              NO STATUS
//app/wiring/app_core:app_layer_test                                     PASSED in 1.3s
//app/wiring/app_core:appearance_shell_test                              PASSED in 2.9s
//app/wiring/app_core:boot_test                                          PASSED in 2.4s
//app/wiring/app_core:feature_flags_boot_test                            PASSED in 1.6s
//app/wiring/app_core:flow_results_hardening_test                        PASSED in 5.2s
//app/wiring/app_core:flow_results_test                                  PASSED in 3.1s
//app/wiring/app_core:formatters_root_test                               PASSED in 0.7s
//app/wiring/app_core:links_and_hooks_test                               PASSED in 0.8s
//app/wiring/app_core:route_nesting_test                                 PASSED in 1.2s
//app/wiring/app_core:router_observers_test                              PASSED in 1.5s
//app/wiring/app_core:router_ref_and_scheme_test                         PASSED in 1.3s
//app/wiring/app_core:sign_in_guard_router_test                          PASSED in 4.0s
//app/wiring/app_core:sign_in_guard_test                                 PASSED in 1.1s
//app/wiring/commerce_wiring:routes_test                                 PASSED in 2.9s
//app/wiring/discovery_wiring:routes_test                                PASSED in 1.1s
//app/wiring/library_wiring:routes_test                                  PASSED in 2.1s
//app/wiring/publishing_wiring:routes_test                               PASSED in 2.2s
//app/wiring/zz_probe_wiring:routes_test                                 PASSED in 0.5s

Executed 18 out of 252 tests: 232 tests pass and 20 were skipped.
There were tests whose specified size is too big. Use the --test_verbose_timeout_warnings command line option to see which ones these are.
```
  - Executed 18 out of 252 tests: 232 tests pass and 20 were skipped.
  - //feature/zz_probe/zz_ld_probe:bdd_test PASSED
  - //feature/zz_probe/zz_ld_probe:architecture_test PASSED
  - //feature/zz_probe/zz_ld_probe:flow_scope_test PASSED
  - //app/wiring/zz_probe_wiring:routes_test PASSED
  - **//app/mini_client:catalogue_test not PASSED**
  - **//app/mini_client:analytics_screens_test not PASSED**

**FAIL T-0074-AC3**
