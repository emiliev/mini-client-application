# T-0042-AC3: incremental and stale handling

| Step | Result | Detail |
|---|---|---|
| a. second sync, no change | PASS | copied=0 unchanged=29, all 29 mtimes equal, 1.9s |
| a. negative control (touched file) | PASS | mtime comparison failed as it must |
| b. edit one freezed model | PASS | copied=1 (feature/characters/characters_list/lib/src/domain/model/character.freezed.dart), 9.3s |
| b. negative control | PASS | an edit copies >= 1 file, so 'copied=0' would have failed |
| b. revert the edit | PASS | copied=1 (back to the original), 2.0s |
| c. add a model | PASS | copied=1, in the manifest, 8.0s |
| c. remove the model | PASS | removed=1, the synced file and its manifest line are gone, 2.0s |
| d. --watch picks up an edit | PASS | 2.9s (limit 5 s; polling every 1s) |

Synced files in the manifest: 29.

Watch log:
```
ide_sync: watching (Ctrl-C to stop)
ide_sync: query: codegen targets under the workspace
ide_sync: build: 44 codegen targets
ide_sync: source change detected
ide_sync: query: codegen targets under the workspace
ide_sync: build: 44 codegen targets
ide_sync: wrote feature/characters/characters_list/lib/src/domain/model/character.freezed.dart
```

**PASS T-0042-AC3**
