# T-0028-AC1: Bazel injectable codegen vs build_runner

```
== 1. Bazel injectable codegen for //spike/di_sample
== 2. Overlay scratch tree .dart_tool/mc_overlay/di_sample_injectable
== 3. Resolve (hosted versions must equal the committed overlay lock)
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
== 5. Compare with bazel-bin
EQUAL   spike/di_sample/lib/src/di/di_initializer.config.dart  sha256 d373324740114210
EQUAL   spike/di_sample/lib/src/badge.injectable.json (shard)  sha256 67d1bed60eff0595
EQUAL   spike/di_sample/lib/src/clock.injectable.json (shard)  sha256 673f48ec2099869d
EQUAL   spike/di_sample/lib/src/greeter.injectable.json (shard)  sha256 e6539d730b0ad761
EQUAL   spike/di_sample/lib/src/greeting_repository.injectable.json (shard)  sha256 0326782b52c11c48
EMPTY   spike/di_sample/lib/src/plain_helper.injectable.json (shard): Bazel [] / build_runner none (expected)
EQUAL   spike/di_sample/lib/src/sample_module.injectable.json (shard)  sha256 a0f460f914f76e73
```

**PASS T-0028-AC1**
