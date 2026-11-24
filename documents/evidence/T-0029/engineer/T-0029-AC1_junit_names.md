# T-0029-AC1: AC tags reach the JUnit case names

`tool/bazelw test --nocache_test_results //spike/bdd_sample:bdd_test`: exit 0
```
//spike/bdd_sample:bdd_test                                              PASSED in 0.7s
Executed 1 out of 1 test: 1 test passes.
```
## JUnit case names (`//spike/bdd_sample:bdd_test` test.xml)
```
"greeting_browse Greeting The greeting is shown [T-0001-AC1]"
"greeting_browse Greeting Tapping the button says goodbye [T-0029-AC1]"
"greeting_table Greeting texts Every label is on screen [T-0029-AC4]"
```
- a case name ends with [T-0001-AC1]
- a case name ends with [T-0029-AC1]
- a case name ends with [T-0029-AC4]

Saved: `T-0029-AC1_bdd_test.xml` and `generated/*.dart` (the bazel-bin outputs).

**PASS T-0029-AC1**
