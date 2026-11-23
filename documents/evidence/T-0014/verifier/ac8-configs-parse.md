| Command | Exit | Unknown option / undefined config lines | First ERROR line |
|---|---|---|---|
| `tool/bazelw build --nobuild --config=lint //spike/...` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=ci --config=cold //spike/...` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=budget16 //spike/...` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=budget16_8c //spike/...` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=profile //spike/...` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=remote-cache //spike/...` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=sim //spike/hello:hello_ios` | 0 | 0 |  |
| `tool/bazelw build --nobuild --config=device //spike/hello:hello_ios` | 1 | 0 | ERROR: /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a43430bcd5c70bf88/spike/hello/BUILD.bazel:139:16: in ios_applic |
| `tool/bazelw build --nobuild --config=device-profile //spike/...` | 0 | 0 |  |
| `tool/bazelw test --nobuild --config=app //spike/...` | 1 | 0 | ERROR: Couldn't start the build. Unable to run tests |
| `tool/bazelw build --nobuild --config=bogus_verifier_cfg //spike/...` | 2 | 1 | ERROR: Config value 'bogus_verifier_cfg' is not defined in any .rc file |
| `tool/bazelw build --nobuild --bogus_verifier_flag //spike/...` | 2 | 1 | ERROR: --bogus_verifier_flag :: Unrecognized option: --bogus_verifier_flag |
| `tool/bazelw --budget16 build --nobuild //spike/...` | 0 | 0 |  |
