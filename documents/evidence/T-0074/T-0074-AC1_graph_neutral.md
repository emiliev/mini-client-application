# T-0074-AC1: the buildgen adoption is graph-neutral

- **Before:** HEAD `133e8daf` (`origin/main`), with the hand-written feature BUILD files.
- **After:** the same tree after `mcgen buildgen --adopt` rewrote all 11 `feature/**/BUILD.bazel` files. `mcgen buildgen --check` then reports 11 up to date.
- Captured with `tool/mcgen/tool/T-0074-AC1_graph.sh DIR` (Bazel 9.3.0, output base `/tmp/mc-ob-T-0074-engineer`).

| View | Before | After | Same |
|---|---|---|---|
| `deps.txt` | 10769 lines, sha256 `a9ccd862c591b352…` | 10769 lines, sha256 `a9ccd862c591b352…` | yes |
| `label_kind.txt` | 10769 lines, sha256 `7fb11c541c81654b…` | 10769 lines, sha256 `7fb11c541c81654b…` | yes |
| `edges.txt` | 29921 lines, sha256 `a5944b810b00711d…` | 29921 lines, sha256 `a5944b810b00711d…` | yes |
| `build.txt` | 7238 lines, sha256 `61208a05e7e991fb…` | 7238 lines, sha256 `61208a05e7e991fb…` | yes |

- `deps.txt`: `bazel query 'deps(//...)'`, the task's literal check: every target and file the build reaches.
- `label_kind.txt`: the same, with each target's rule kind.
- `edges.txt`: every dependency edge of `deps(//...)` (`--output=graph --nograph:factored`), as `from -> to`.
- `build.txt`: every in-repo target's attributes after macro expansion (`bazel query '//...' --output=build`). Comment lines (BUILD file locations, macro call stacks) and `generator_location` are dropped, and each list's items are sorted.
  - Equal means no attribute of any target changed except the order of list items, which the adoption sorts (`_FREEZED`, `_CODEGEN`, trivia_quiz's `_TEST_DEPS`).
  - The first capture of `build.txt` kept the call-stack comment lines (`#   …/BUILD.bazel:306:13 in <toplevel>`), which differ only because statements moved. The script now drops every comment line, and both captures were re-filtered the same way.

What the adoption changed (`git diff -- feature`): `# keep` on the hand-written list items the import graph does not explain, sorted dicts and lists, one statement order (auth_signin's `bloc_guards_test` before `unit_test`), and three files' bespoke statements moved verbatim into the `# mcgen:keep build` hand region: trivia_quiz's engine lane, `engine_test`, `architecture_test` and `outline_matches_contract_test`; the `size = "medium"` legacy `golden_test` of library_reading_list_editor and store_home.
