# T-0069-AC3: a throwaway list-detail module

HEAD `7a28a3e9`

- PASS: mcgen gen zz_ld_probe
  - 44 files generated
- PASS: mcgen gen --check zz_ld_probe (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_ld_probe/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_ld_probe/...
  - BDD scenarios: 7 passed, 0 failed
  - //feature/zz_probe/zz_ld_probe:architecture_test PASSED
  - //feature/zz_probe/zz_ld_probe:bdd_test PASSED
  - //feature/zz_probe/zz_ld_probe:contract_test PASSED
  - //feature/zz_probe/zz_ld_probe:flow_scope_test PASSED

**PASS T-0069-AC3**
