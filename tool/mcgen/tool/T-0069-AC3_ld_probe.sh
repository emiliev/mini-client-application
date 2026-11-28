#!/bin/bash
# T-0069-AC3: the list-detail archetype generalises past its exemplar. A
# throwaway LD module (tool/mcgen/test/fixtures/zz_ld_probe/mcgen.yaml: other
# entities, fields, endpoint, nouns and page size, no filter, no section) is
#   1. generated into feature/zz_probe/zz_ld_probe by `mcgen gen`;
#   2. analysed with mc_analysis (`bazel build --config=lint`), with no issue;
#   3. tested under Bazel: its BDD suite (the template steps over the
#      mocked backend), contract, flow-scope and architecture tests;
# and deleted again, whatever happens. Never committed (task scope).
#   tool/mcgen/tool/T-0069-AC3_ld_probe.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP (e.g. "--output_base=/tmp/mc-ob-T-0069-engineer") picks the
# Bazel server, as for every tool/checks script.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../checks/lib.sh"
cd "$REPO" || exit 2
PROBE=feature/zz_probe/zz_ld_probe
if [[ -e feature/zz_probe ]]; then
  echo "feature/zz_probe exists; remove it first (this script owns it)" >&2
  exit 2
fi
read -r -a DART <<< "${MC_DART:-fvm dart}"
log="$(mktemp)"
trap 'rm -rf "$REPO/feature/zz_probe"; rm -f "$log"' EXIT
rc=0
step() {  # step <label> <command...>
  local label="$1"; shift
  if "$@" > "$log" 2>&1; then
    report "- PASS: $label"
  else
    report "- **FAIL**: $label" '```' "$(plain "$log" | tail -30)" '```'
    rc=1
  fi
}
report "# T-0069-AC3: a throwaway list-detail module" "" "HEAD \`$(git rev-parse --short HEAD)\`" ""
mkdir -p "$PROBE"
cp tool/mcgen/test/fixtures/zz_ld_probe/mcgen.yaml "$PROBE/mcgen.yaml"
step "mcgen gen zz_ld_probe" "${DART[@]}" run tool/mcgen/bin/mcgen.dart gen zz_ld_probe
report "  - $(find "$PROBE" -type f | wc -l | tr -d ' ') files generated"
step "mcgen gen --check zz_ld_probe (idempotent)" "${DART[@]}" run tool/mcgen/bin/mcgen.dart gen --check zz_ld_probe
step "bazel build --config=lint //$PROBE/... (mc_analysis, no issue)" bzw build --config=lint "//$PROBE/..."
step "bazel test //$PROBE/... (uncached)" bzw test --nocache_test_results --test_output=errors "//$PROBE/..."
if [[ -f "bazel-testlogs/$PROBE/bdd_test/test.log" ]]; then
  report "  - BDD scenarios: $(grep -c '^  PASS ' "bazel-testlogs/$PROBE/bdd_test/test.log") passed, $(grep -c '^  FAIL ' "bazel-testlogs/$PROBE/bdd_test/test.log") failed"
fi
for t in architecture_test bdd_test contract_test flow_scope_test; do
  if grep -q "PASSED" "$log" && plain "$log" | grep -q "//$PROBE:$t .*PASSED"; then
    report "  - //$PROBE:$t PASSED"
  else
    report "  - **//$PROBE:$t not PASSED**"
    rc=1
  fi
done
finish T-0069-AC3 "$rc"
