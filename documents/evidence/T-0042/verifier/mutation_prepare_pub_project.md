# T-0033 e2e prepare: fresh output base, no stale or junk files

## prepare from a fresh output base (/tmp/mc-ob-T-0042-verifier-fresh): exit 69
```
==> cquery: the generated Dart files under //app/mini_client:mini_client_lib
==> bazel build of the 6 targets that make them
==> copying the repo's own files to /var/folders/fj/1dh73k217x5gx70k2qwdlzr80000gn/T/tmp.ZxDloLgzfR/p
==> copying the 18 generated files from the execroot
GENERATED_FILES=18
==> bundling the e2e config as assets/app_config.json
==> flutter create --platforms=ios (adds the Xcode project; keeps existing files)
```
```
==> cquery: the generated Dart files under //app/mini_client:mini_client_lib
==> bazel build of the 6 targets that make them
==> copying the repo's own files to /var/folders/fj/1dh73k217x5gx70k2qwdlzr80000gn/T/tmp.ZxDloLgzfR/p
==> copying the 18 generated files from the execroot
GENERATED_FILES=18
==> bundling the e2e config as assets/app_config.json
==> flutter create --platforms=ios (adds the Xcode project; keeps existing files)
Error on line 53, column 3: Duplicate mapping key.
   ╷
53 │   assets:
   │   ^^^^^^
   ╵
```

**FAIL T-0033-e2e_prepare**
