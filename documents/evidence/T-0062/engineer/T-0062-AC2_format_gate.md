# T-0062-AC2: the format gate in a fresh worktree

Worktree: `/var/folders/fj/1dh73k217x5gx70k2qwdlzr80000gn/T//mc-T-0062-engineer-wt.P0d5Gn` (detached at `d5106f0`), removed at the end.

- fresh: no `.dart_tool` in the worktree
- control: a bare `dart format` with no `.dart_tool` reports 137 false changes
- the gate passes in the fresh worktree: `Formatted 899 files (0 changed) in 1.58 seconds.`
- it ran `fvm dart pub get --offline` itself
- negative control 1: an unformatted line in `tool/loc/lib/count.dart` fails the gate
- negative control 2: an unformatted line in `third_party/flow_builder` and a `.dart` file under `documents/` do not fail the gate
- provenance control: with the line added to flow_builder the provenance check fails (it sees the file, so a format run there would be noticed)
- after the revert the flow_builder provenance check passes: `**PASS T-0035-AC4-provenance**`
- the worktree is clean after the controls (pub get leaves no tracked change)

**PASS T-0062-AC2**
