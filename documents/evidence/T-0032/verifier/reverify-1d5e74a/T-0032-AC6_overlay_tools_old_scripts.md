# T-0032-AC6: overlay helpers parse pubspec blocks

Scripts: `/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/r/oldtools`

| Case | Result |
|---|---|
| overlay_deps.py over a block with a blank line and a comment | WRONG: first b b; |
| add_dep.py adds a dev-only package to dependencies, once; keeps dio once | WRONG:   dio: any; |

**FAIL T-0032-AC6-overlay-tools**
