# T-0030 coverage (Verifier)

Measured with the Verifier's own LCOV parser ([`cov.py.txt`](cov.py.txt)). It takes the union (max hit count per line) of every per-target `coverage.dat` of the package, counts `lib/` files only, and excludes the generated `.freezed.dart`. The run was on a clean tree at `63dbaf4`.

```
$ tool/bazelw --output_base=/tmp/mc-ob-T-0030-verifier coverage --nocache_test_results \
    //utility/mc_paging:paging_controller_test //utility/mc_paging:debounced_query_test \
    //utility/mc_paging:search_history_test //utility/mc_paging:paged_state_test \
    //utility/mc_media:api_image_test //utility/mc_media:media_scope_test
rc=0
$ python3 -I cov.py <output_base>/execroot/_main/bazel-out mc_paging
lib/src/page.dart: 12/12 missed=[]
lib/src/paging_controller.dart: 49/49 missed=[]
lib/src/query/debounced_query.dart: 17/17 missed=[]
lib/src/query/search_history.dart: 20/20 missed=[]
TOTAL mc_paging 98/98 = 100.0%
$ python3 -I cov.py <output_base>/execroot/_main/bazel-out mc_media
lib/src/api_image.dart: 14/14 missed=[]
lib/src/media_scope.dart: 7/7 missed=[]
TOTAL mc_media 21/21 = 100.0%
```

Two files have no executable lines, so they report no line data:
- `lib/src/paged_state.dart`: a `const factory` only.
- `lib/src/image_resolver.dart`: abstract interfaces.

These totals match the engineer's `coverage.txt`.
