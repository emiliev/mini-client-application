# T-0056-AC8: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/store/store_home`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| retrofit client | `lib/src/domain/api/store_home_api.g.dart` | yes | yes |
| json part | `lib/src/domain/model/store_dto.g.dart` | yes | yes |
| freezed (DTO) | `lib/src/domain/model/store_dto.freezed.dart` | yes | yes |
| freezed (domain) | `lib/src/domain/model/store.freezed.dart` | yes | yes |
| freezed (flow state) | `lib/src/flow/store_home_flow_state.freezed.dart` | yes | yes |
| freezed (banners bloc state) | `lib/src/presentation/bloc/banners_bloc.freezed.dart` | yes | yes |
| freezed (cart_summary bloc state) | `lib/src/presentation/bloc/cart_summary_bloc.freezed.dart` | yes | yes |
| freezed (categories bloc state) | `lib/src/presentation/bloc/categories_bloc.freezed.dart` | yes | yes |
| freezed (category_products bloc state) | `lib/src/presentation/bloc/category_products_bloc.freezed.dart` | yes | yes |
| freezed (deals bloc state) | `lib/src/presentation/bloc/deals_bloc.freezed.dart` | yes | yes |
| freezed (featured bloc state) | `lib/src/presentation/bloc/featured_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard | `lib/src/presentation/bloc/deals_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/store_home_l10n.dart` | yes | yes |
| gen-l10n (de) | `lib/src/l10n/store_home_l10n_de.dart` | yes | yes |
| BDD test | `test/feature/store_home_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/store_home_sections_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/store_home_cart_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/store_home_l10n_test.dart` | yes | n/a (bazel-out only) |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

Hand-written paths the scoped ignore rules must leave visible:

| File | git |
|---|---|
| `test/feature/helpers_test.dart` | visible |
| `lib/src/app.config.dart` | visible |
| `test/feature/step/i_open_the_store.dart` | visible |

All declared outputs of the package's generator targets (30):

```
lib/src/di/di_initializer.config.dart
lib/src/domain/api/store_home_api.g.dart
lib/src/domain/api/store_home_api.injectable.json
lib/src/domain/api/store_home_api.retrofit.g.part
lib/src/domain/model/store.freezed.dart
lib/src/domain/model/store_dto.freezed.dart
lib/src/domain/model/store_dto.g.dart
lib/src/domain/model/store_dto.json_serializable.g.part
lib/src/domain/repository/store_home_repository.injectable.json
lib/src/flow/store_home_flow_state.freezed.dart
lib/src/l10n/store_home_l10n.dart
lib/src/l10n/store_home_l10n_de.dart
lib/src/l10n/store_home_l10n_en.dart
lib/src/presentation/bloc/banners_bloc.freezed.dart
lib/src/presentation/bloc/banners_bloc.injectable.json
lib/src/presentation/bloc/cart_summary_bloc.freezed.dart
lib/src/presentation/bloc/cart_summary_bloc.injectable.json
lib/src/presentation/bloc/categories_bloc.freezed.dart
lib/src/presentation/bloc/categories_bloc.injectable.json
lib/src/presentation/bloc/category_products_bloc.freezed.dart
lib/src/presentation/bloc/category_products_bloc.injectable.json
lib/src/presentation/bloc/deals_bloc.freezed.dart
lib/src/presentation/bloc/deals_bloc.injectable.json
lib/src/presentation/bloc/featured_bloc.freezed.dart
lib/src/presentation/bloc/featured_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/store_home_cart_test.dart
test/feature/store_home_l10n_test.dart
test/feature/store_home_sections_test.dart
test/feature/store_home_test.dart
```

**PASS T-0056-AC8-not-committed**
