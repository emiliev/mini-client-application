# T-0072-AC3: a throwaway section-detail module

HEAD `e60ad390`

- PASS: mcgen gen zz_sc_probe
  - 45 files generated
- PASS: mcgen gen --check zz_sc_probe (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_sc_probe/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_sc_probe/... (uncached)
  - BDD scenarios: 8 passed, 0 failed
  - //feature/zz_probe/zz_sc_probe:architecture_test PASSED
  - //feature/zz_probe/zz_sc_probe:bdd_test PASSED
  - //feature/zz_probe/zz_sc_probe:flow_scope_test PASSED

**PASS T-0072-AC3**
