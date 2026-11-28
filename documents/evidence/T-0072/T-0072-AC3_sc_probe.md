# T-0072-AC3: a throwaway section-detail module

HEAD `e3be481f`

- PASS: mcgen gen zz_sc_probe
  - 45 files generated
- PASS: mcgen gen --check zz_sc_probe (idempotent)
- PASS: mcgen gen zz_sc_plain
  - 35 files generated
- PASS: mcgen gen --check zz_sc_plain (idempotent)
- PASS: mcgen gen zz_sc_story
  - 36 files generated
- PASS: mcgen gen --check zz_sc_story (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_sc_probe/... and zz_sc_plain (uncached)
  - BDD scenarios: 8 passed, 0 failed
  - zz_sc_plain BDD scenarios: 1 passed
  - //feature/zz_probe/zz_sc_probe:architecture_test PASSED
  - //feature/zz_probe/zz_sc_probe:bdd_test PASSED
  - //feature/zz_probe/zz_sc_probe:flow_scope_test PASSED

**PASS T-0072-AC3**
