# T-0014-AC8: configs parse with no unknown option or config

| Command | Exit | Unknown option / config lines |
|---|---|---|
| `tool/bazelw build --nobuild --config=lint //spike/...` | 0 | 0 |
| `tool/bazelw build --nobuild --config=ci --config=cold //spike/...` | 0 | 0 |
| `tool/bazelw build --nobuild --config=budget16 //spike/...` | 0 | 0 |
| `tool/bazelw --budget16 build --nobuild //spike/...` | 0 | 0 |
| `tool/bazelw build --nobuild --config=budget16_8c //spike/...` | 0 | 0 |
| `tool/bazelw build --nobuild --config=profile //spike/...` | 0 | 0 |
| `tool/bazelw build --nobuild --config=remote-cache //spike/...` | 0 | 0 |
| `tool/bazelw build --nobuild --config=sim //spike/hello:hello_ios` | 0 | 0 |
| `tool/bazelw build --nobuild --config=device-profile //spike/...` | 0 | 0 |
| `tool/bazelw test --nobuild --config=app //spike/...` | 1 | 0 |
| `tool/bazelw build --nobuild --config=no_such_config //spike/...` (negative control) | 2 | 1 |

Negative control: Bazel reports an undefined config with a non-zero exit, so a zero exit with 0 matching lines means the config parsed.

## T-0014-AC5
```
$ fvm flutter --version   # in agent-a5c44fd531dc49825 (repo root, .fvmrc = {"flutter":"3.47.7"})
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (7 weeks ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (1 months ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0
```

Note on `test --config=app`: exit 1 is `ERROR: Couldn't start the build. Unable to run tests` after `WARNING: All specified test targets were excluded by filters`. `//spike/...` has no `app`-tagged test yet, so the config parsed and its tag filter worked. It is not an option error.

`~` in `--disk_cache` / `--repository_cache` expands to `$HOME`: the caches live at `~/.cache/mc-bazel/{disk,repo}`, and no literal `~` directory appears in the workspace.
