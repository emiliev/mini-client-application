# T-0075-AC3: throwaway form/wizard modules

HEAD `9e2a95d9`

## zz_fw_probe
- PASS: mcgen gen zz_fw_probe
- PASS: mcgen wire feature/zz_probe/zz_fw_probe (its flow scope)
- PASS: mcgen buildgen feature/zz_probe/zz_fw_probe
  - 34 files generated
- PASS: mcgen gen --check zz_fw_probe (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_fw_probe/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_fw_probe/... (uncached)
  - BDD scenarios: 7 passed, 0 failed
  - //feature/zz_probe/zz_fw_probe:architecture_test PASSED
  - //feature/zz_probe/zz_fw_probe:bdd_test PASSED
  - //feature/zz_probe/zz_fw_probe:flow_scope_test PASSED
## zz_fw_plain
- PASS: mcgen gen zz_fw_plain
- PASS: mcgen wire feature/zz_probe/zz_fw_plain (its flow scope)
- PASS: mcgen buildgen feature/zz_probe/zz_fw_plain
  - 33 files generated
- PASS: mcgen gen --check zz_fw_plain (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_fw_plain/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_fw_plain/... (uncached)
  - BDD scenarios: 7 passed, 0 failed
  - //feature/zz_probe/zz_fw_plain:architecture_test PASSED
  - //feature/zz_probe/zz_fw_plain:bdd_test PASSED
  - //feature/zz_probe/zz_fw_plain:flow_scope_test PASSED

**PASS T-0075-AC3**
