# T-0033 e2e prepare: fresh output base, no stale or junk files

## prepare from a fresh output base (/tmp/mc-ob-T-0033-fresh): exit 0
```
==> cquery: the generated Dart files under //app/mini_client:mini_client_lib
==> bazel build of the 21 targets that make them
==> copying the repo's own files to /var/folders/fj/1dh73k217x5gx70k2qwdlzr80000gn/T/tmp.aGSmCh1YmO/p
==> copying the 37 generated files from the execroot
GENERATED_FILES=37
==> bundling the e2e config as assets/app_config.json
==> flutter create --platforms=ios (adds the Xcode project; keeps existing files)
==> flutter pub get
E2E_PROJECT=/var/folders/fj/1dh73k217x5gx70k2qwdlzr80000gn/T/tmp.aGSmCh1YmO/p/app/mini_client
```
## verify: FAIL
```
generated-looking files: 18, built outputs: 37
```
## negative control (stale file in the copy): verify FAILED as it must
## negative control (junk generated-looking file): verify FAILED as it must

**FAIL T-0033-e2e_prepare**
