# T-0076-AC3: two throwaway dashboard modules

HEAD `244bcb32`

## zz_db_a
- PASS: mcgen gen zz_db_a
  - 59 files after generation
- PASS: mcgen gen --check zz_db_a (idempotent)
## zz_db_b
- PASS: mcgen gen zz_db_b
  - 105 files after generation
- PASS: mcgen gen --check zz_db_b (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_db_a/... (mc_analysis, no issue)
- PASS: bazel build --config=lint //feature/zz_probe/zz_db_b/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_db_a/... (uncached)
  - BDD scenarios: 4 passed, 0 failed
  - //feature/zz_probe/zz_db_a:architecture_test PASSED
  - //feature/zz_probe/zz_db_a:bdd_test PASSED
  - //feature/zz_probe/zz_db_a:contract_test PASSED
- PASS: bazel test //feature/zz_probe/zz_db_b/... (uncached)
  - BDD scenarios: 78 passed, 0 failed
  - //feature/zz_probe/zz_db_b:architecture_test PASSED
  - //feature/zz_probe/zz_db_b:bdd_test PASSED
  - //feature/zz_probe/zz_db_b:contract_test PASSED
  - //feature/zz_probe/zz_db_b:flow_scope_test PASSED

**PASS T-0076-AC3**
