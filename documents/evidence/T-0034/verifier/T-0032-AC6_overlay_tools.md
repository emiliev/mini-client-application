# T-0032-AC6: overlay helpers parse pubspec blocks

Scripts: `tool/build_runner_overlay`

| Case | Result |
|---|---|
| overlay_deps.py over a block with a blank line and a comment | ok |
| add_dep.py adds a dev-only package to dependencies, once; keeps dio once | ok |

**PASS T-0032-AC6-overlay-tools**
