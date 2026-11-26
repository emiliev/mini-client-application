# T-0042-AC1: the analyzer on a fresh clone, before and after tool/ide_sync

Fresh clone of `b13f51f78ac33f9ac8a1b9803da2bfdeec72994f`, workspace packages: `app feature utility spike third_party tool/l10n_check tool/mc_arch_check`.

## Before the sync: 176 errors, 11 warnings
```
  86 undefined_getter
  28 undefined_method
  17 redirect_to_non_class
  13 mixin_of_non_class
  11 uri_does_not_exist
  10 uri_has_not_been_generated
  7 undefined_identifier
  4 argument_type_not_assignable
```

Examples:
```
  error - app/mini_client/lib/src/router/app_router.dart:21:8 - Undefined name '$appRoutes'. Try correcting the name to one that is defined, or defining the name. - undefined_identifier
  error - app/mini_client/lib/src/router/app_routes.dart:13:6 - Target of URI hasn't been generated: 'package:mini_client/src/router/app_routes.g.dart'. Try running the generator that will generate the file referenced by the URI. - uri_has_not_been_generated
  error - app/wiring/universe_wiring/lib/src/di/di_initializer.dart:6:8 - Target of URI doesn't exist: 'package:universe_wiring/src/di/di_initializer.config.dart'. Try creating the file referenced by the URI, or try using a URI for a file that does exist. - uri_does_not_exist
  error - app/wiring/universe_wiring/lib/src/routes/characters_routes.dart:6:6 - Target of URI hasn't been generated: 'package:universe_wiring/src/routes/characters_routes.g.dart'. Try running the generator that will generate the file referenced by the URI. - uri_has_not_been_generated
```

- before: errors about missing generated parts, as expected

## tool/ide_sync --env dev (fresh output base, warm disk cache): exit 0 in 11 s
```
ide_sync: wrote app/sandbox/universe_sandbox/assets/app_config.json
ide_sync: flutter create --platforms=ios for mini_client (Xcode project, git-ignored)
ide_sync: flutter create --platforms=ios for universe_sandbox (Xcode project, git-ignored)
IDE_SYNC copied=23 unchanged=0 removed=0 skipped=0 total=23
```

## After the sync: 0 errors, 0 warnings (23 synced files)
```
   info - utility/mc_fixtures_characters/tool/update_snapshots.dart:28:22 - Statement should be on a separate line. Try moving the statement to a new line. - always_put_control_body_on_new_line
   info - utility/mc_fixtures_comics/tool/update_snapshots.dart:28:22 - Statement should be on a separate line. Try moving the statement to a new line. - always_put_control_body_on_new_line

4 issues found.
```

- after: zero errors and zero warnings
- negative control: without `character.freezed.dart` the same analyzer run reports 14 errors

**PASS T-0042-AC1**
