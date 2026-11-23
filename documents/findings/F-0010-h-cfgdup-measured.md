# F-0010: H-CFGDUP measured: codegen runs once per configuration; kernels differ by variant

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0014)
- **Type:** Benchmark
- **Related:** T-0014-AC4, plan 03 X9 and §4.7, R14, P5 KD7, U-D8, [evidence](../evidence/T-0014/engineer/ac4-h-cfgdup.md)

## Summary
In one Bazel server, a simulator app build (`--config=sim`) followed by a host widget test reruns **every** codegen action: **3 of 3 DartCodegen actions are duplicated**, with identical inputs and outputs under two output roots (`darwin_arm64-fastbuild` and `ios_sim_arm64-dbg-…`). Kernels are a different case: **12 of 32** non-exec targets are compiled in both configurations, but as different products (`<pkg>.flutter.kmod` for the test, `<pkg>.app_debug.flutter.kmod` for the app). Only 1 kernel (the rules_dart `greeting.kmod`) is an exact duplicate. 95 exec-configuration actions (rules' own tools) were shared between the two invocations.

## Method
`tool/bazelw clean`, then `--config=cold` (no disk cache) and `--execution_log_json_file` for both invocations, counted with `documents/evidence/T-0014/engineer/cfgdup.py`. Identity = (mnemonic, target label, output path minus `bazel-out/<config>/`).

## Implications
- At S2 (about 6k codegen actions, plan 03 §4.7), mixing app builds and tests doubles codegen CPU, roughly 30 more CPU minutes cold. Keep the separate invocations (R14, P5 KD7). Path mapping (U-D8) would remove the codegen duplicates, because the inputs are identical.
- Path mapping would **not** remove the kernel duplicates. The app's debug kernels and the test kernels are different variants, so sharing them would need a rules_flutter change (one kernel variant for tests and debug apps). Add this to the P4 hypothesis list.
- Re-measure at S2 with P4's harness. The spike's counts are small, but the shape is structural.
