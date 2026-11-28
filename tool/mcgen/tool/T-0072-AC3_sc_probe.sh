#!/bin/bash
# T-0072-AC3: the section-detail archetype generalises past its exemplars. A
# throwaway SC module (plus two more, see below) (tool/mcgen/test/fixtures/zz_sc_probe/mcgen.yaml: other
# nouns, one hand-over with its id on the entity, no second request, no inner
# page, no analytics) is
#   1. generated into feature/zz_probe/zz_sc_probe by `mcgen gen`;
#   2. analysed with mc_analysis (`bazel build --config=lint`), with no issue;
#   3. tested under Bazel: its BDD suite (the template steps over the
#      mocked backend), flow-scope and architecture tests;
# and deleted again, whatever happens. Never committed (task scope).
#   tool/mcgen/tool/T-0072-AC3_sc_probe.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP (e.g. "--output_base=/tmp/mc-ob-T-0072-engineer") picks the
# Bazel server, as for every tool/checks script.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../checks/lib.sh"
cd "$REPO" || exit 2
PROBE=feature/zz_probe/zz_sc_probe
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
report "# T-0072-AC3: a throwaway section-detail module" "" "HEAD \`$(git rev-parse --short HEAD)\`" ""
# zz_sc_probe: the full probe (tests run). zz_sc_plain: no hand-over (tests
# run). zz_sc_story: a two-word item, String ids, nested DTOs, two hand-overs
# (analysed and built only; its backend has no String-id route).
for m in zz_sc_probe zz_sc_plain zz_sc_story; do
  mkdir -p "feature/zz_probe/$m"
  cp "tool/mcgen/test/fixtures/$m/mcgen.yaml" "feature/zz_probe/$m/mcgen.yaml"
  step "mcgen gen $m" "${DART[@]}" run tool/mcgen/bin/mcgen.dart gen "$m"
  report "  - $(find "feature/zz_probe/$m" -type f | wc -l | tr -d ' ') files generated"
  step "mcgen gen --check $m (idempotent)" "${DART[@]}" run tool/mcgen/bin/mcgen.dart gen --check "$m"
done
step "bazel build --config=lint //feature/zz_probe/... (mc_analysis, no issue)" bzw build --config=lint "//feature/zz_probe/..."
step "bazel test //$PROBE/... and zz_sc_plain (uncached)" bzw test --nocache_test_results --test_output=errors "//$PROBE/..." "//feature/zz_probe/zz_sc_plain/..."
if [[ -f "bazel-testlogs/$PROBE/bdd_test/test.log" ]]; then
  report "  - BDD scenarios: $(grep -c '^  PASS ' "bazel-testlogs/$PROBE/bdd_test/test.log") passed, $(grep -c '^  FAIL ' "bazel-testlogs/$PROBE/bdd_test/test.log") failed"
fi
if [[ -f "bazel-testlogs/feature/zz_probe/zz_sc_plain/bdd_test/test.log" ]]; then
  report "  - zz_sc_plain BDD scenarios: $(grep -c '^  PASS ' "bazel-testlogs/feature/zz_probe/zz_sc_plain/bdd_test/test.log") passed"
fi
for t in architecture_test bdd_test flow_scope_test; do
  if grep -q "PASSED" "$log" && plain "$log" | grep -q "//$PROBE:$t .*PASSED"; then
    report "  - //$PROBE:$t PASSED"
  else
    report "  - **//$PROBE:$t not PASSED**"
    rc=1
  fi
done
finish T-0072-AC3 "$rc"
