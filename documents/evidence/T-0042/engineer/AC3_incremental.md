# T-0042-AC3: incremental and stale handling

| Step | Result | Detail |
|---|---|---|
| a. second sync, no change | PASS | copied=0 unchanged=23, all 23 mtimes equal, 1.5s |
| a. negative control (touched file) | PASS | mtime comparison failed as it must |
| b. edit one freezed model | PASS | copied=1 (feature/characters/characters_list/lib/src/domain/model/character.freezed.dart), 1.6s |
| b. negative control | PASS | an edit copies >= 1 file, so 'copied=0' would have failed |
| b. revert the edit | PASS | copied=1 (back to the original), 1.6s |
| c. add a model | PASS | copied=1, in the manifest, 1.6s |
| c. remove the model | PASS | removed=1, the synced file and its manifest line are gone, 1.7s |
| d. --watch picks up an edit | PASS | 2.5s (limit 5 s; polling every 1s) |

Synced files in the manifest: 23.

Watch log:
```
ide_sync: watching (Ctrl-C to stop)
ide_sync: query: codegen targets under the workspace
ide_sync: build: 42 codegen targets
ide_sync: source change detected
ide_sync: query: codegen targets under the workspace
ide_sync: build: 42 codegen targets
ide_sync: wrote feature/characters/characters_list/lib/src/domain/model/character.freezed.dart
```

**PASS T-0042-AC3**
