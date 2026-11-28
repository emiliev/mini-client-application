# T-0074-AC4: the archetype probes still pass with wire and buildgen

After the P-126 move, each archetype probe runs `mcgen gen`, then `mcgen wire <module dir>` (its flow scope) and, for list-detail and section-detail, `mcgen buildgen <module dir>` (its BUILD file). The search skeleton still writes its own owned BUILD file (F-0074 §6). Run on the branch after merging T-0072 and T-0073. T-0072's script is committed without the exec bit (mode 100644 on main), so it ran as `bash tool/mcgen/tool/T-0072-AC3_sc_probe.sh`.

## T-0069-AC3_ld_probe

### T-0069-AC3: a throwaway list-detail module

HEAD `df9474bd`

- PASS: mcgen gen zz_ld_probe
- PASS: mcgen wire feature/zz_probe/zz_ld_probe (its flow scope)
- PASS: mcgen buildgen feature/zz_probe/zz_ld_probe
  - 44 files generated
  - outline: 2 Examples rows in zz_ld_probe.feature
  - en_XA: ` "zzLdProbeShown": "[{count, plural, =0{Ñó çóɱíçš} =1{Óñé çóɱíç} other{{count} çóɱíçš}} ~~~~~~~~~~~~~~~~~~~~~~~~~~~]",  "zzLdProbeGreeting": "[Ĥéļļó {name} ~~~~~]" `
- PASS: mcgen gen --check zz_ld_probe (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_ld_probe/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_ld_probe/... (uncached)
  - BDD scenarios: 9 passed, 0 failed
  - //feature/zz_probe/zz_ld_probe:architecture_test PASSED
  - //feature/zz_probe/zz_ld_probe:bdd_test PASSED
  - //feature/zz_probe/zz_ld_probe:contract_test PASSED
  - //feature/zz_probe/zz_ld_probe:flow_scope_test PASSED

**PASS T-0069-AC3**


## T-0072-AC3_sc_probe

### T-0072-AC3: a throwaway section-detail module

HEAD `df9474bd`

- PASS: mcgen gen zz_sc_probe
- PASS: mcgen wire feature/zz_probe/zz_sc_probe (its flow scope)
- PASS: mcgen buildgen feature/zz_probe/zz_sc_probe
  - 45 files generated
- PASS: mcgen gen --check zz_sc_probe (idempotent)
- PASS: mcgen gen zz_sc_plain
- PASS: mcgen wire feature/zz_probe/zz_sc_plain (its flow scope)
- PASS: mcgen buildgen feature/zz_probe/zz_sc_plain
  - 35 files generated
- PASS: mcgen gen --check zz_sc_plain (idempotent)
- PASS: mcgen gen zz_sc_story
- PASS: mcgen wire feature/zz_probe/zz_sc_story (its flow scope)
- PASS: mcgen buildgen feature/zz_probe/zz_sc_story
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


## T-0073-AC3_sr_probe

### T-0073-AC3: a throwaway search module

HEAD `df9474bd`

- PASS: mcgen gen zz_sr_probe
- PASS: mcgen wire feature/zz_probe/zz_sr_probe (its flow scope)
  - 47 files generated
  - en_XA: ` "zzSrProbeEmptyMessage": "[Ñó çóɱíç’š ţíţļé šţàŕţš ŵíţĥ “{query}”. Çĥéçķ ţĥé šþéļļíñĝ. ~~~~~~~~~~~~~~~~~~~~~~~~]", `
- PASS: mcgen gen --check zz_sr_probe (idempotent)
- PASS: bazel build --config=lint //feature/zz_probe/zz_sr_probe/... (mc_analysis, no issue)
- PASS: bazel test //feature/zz_probe/zz_sr_probe/... (uncached)
  - BDD scenarios: 8 passed, 0 failed
  - //feature/zz_probe/zz_sr_probe:architecture_test PASSED
  - //feature/zz_probe/zz_sr_probe:bdd_test PASSED
  - //feature/zz_probe/zz_sr_probe:contract_test PASSED
  - //feature/zz_probe/zz_sr_probe:flow_scope_test PASSED

**PASS T-0073-AC3**

