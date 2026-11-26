# T-0038 Verifier: purity negative control

Mutation: `//utility/mc_fixtures_media` added to the `mc_fixtures_comics` dart_library deps.
```diff
diff --git a/utility/mc_fixtures_comics/BUILD.bazel b/utility/mc_fixtures_comics/BUILD.bazel
index 572ba37..3ebdb29 100644
--- a/utility/mc_fixtures_comics/BUILD.bazel
+++ b/utility/mc_fixtures_comics/BUILD.bazel
@@ -14,6 +14,7 @@ dart_library(
     srcs = glob(["lib/**/*.dart"]),
     language_version = _LANG,
     deps = [
+        "//utility/mc_fixtures_media",
         "//utility/mc_media",
         "//utility/mc_mocked_backend",
     ],
```
Flutter markers in `deps(//utility/mc_fixtures_comics:mc_fixtures_comics)`:
```
@flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
@flutter_sky_engine//sky_engine:lib/_http/crypto.dart
@flutter_sky_engine//sky_engine:lib/_http/embedder_config.dart
```
Result: markers found, the closure check would FAIL (control works).
