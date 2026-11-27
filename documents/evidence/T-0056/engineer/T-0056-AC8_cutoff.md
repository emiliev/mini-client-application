# T-0056-AC8: a bloc body edit cuts off before retrofit and the injectable aggregate

Edit: `assert('cutoff-1795789451-2219'.isNotEmpty);` added to the `_Open` case of `DealsBloc._onEvent` in `feature/store/store_home/lib/src/presentation/bloc/deals_bloc.dart`, then `build //feature/store/store_home:store_home` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `92c89703d9ad74d0` | `92c89703d9ad74d0` |
| store_home_api.g.dart sha256 | `ef942a77d8c02777` | `ef942a77d8c02777` |

| Check | Result |
|---|---|
| positive control: bloc freezed action executed | yes |
| positive control: bloc injectable shard executed | yes |
| aggregate spawns that were not cache hits | none |
| retrofit part / API combine / DTO json spawns that ran | none |
| bloc files among the retrofit action's inputs | 0 |
| bloc file among the aggregate action's inputs | 0 |

Spawns in the execution log after the edit:

```
DartCodegen	//feature/store/store_home:_di_config_src_domain_api_store_home_api_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_store_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_domain_repository_store_home_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_banners_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_presentation_bloc_banners_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_cart_summary_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_presentation_bloc_cart_summary_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_categories_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_presentation_bloc_categories_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_category_products_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_presentation_bloc_category_products_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_deals_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_presentation_bloc_deals_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_featured_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/store/store_home:_di_config_src_presentation_bloc_featured_bloc_inj	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/store/store_home:store_home	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/domain/api/store_home_api.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/domain/repository/store_home_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/presentation/bloc/banners_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/presentation/bloc/cart_summary_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/presentation/bloc/categories_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/presentation/bloc/category_products_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/presentation/bloc/deals_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/store/store_home/lib/src/presentation/bloc/featured_bloc.injectable.json
feature/store/store_home/lib/src/di/di_initializer.dart
```

**PASS T-0056-AC8-cutoff**
