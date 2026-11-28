#!/bin/bash
# T-0076-AC3: the dashboard archetype generalises past its one exemplar. Two
# throwaway DB modules (tool/mcgen/test/fixtures/zz_db_a and zz_db_b: the spec
# and the hand-written owned files of each) are, one after the other,
#   1. copied into feature/zz_probe/<module>;
#   2. generated there by `mcgen gen` (the managed files);
#   3. analysed with mc_analysis (`bazel build --config=lint`), with no issue;
#   4. tested under Bazel: BDD, contract, architecture and flow-scope tests;
# and deleted again, whatever happens. Never committed (task scope).
#   zz_db_a: 3 sections (deals, featured, cart), no detail page, no flag.
#   zz_db_b: 5 sections, a flagged section (spotlight), the signed-in cart
#            and a paged detail page (a category's products).
#   tool/mcgen/tool/T-0076-AC3_db_probe.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP (e.g. "--output_base=/tmp/mc-ob-T-0076-engineer") picks the
# Bazel server, as for every tool/checks script.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../checks/lib.sh"
cd "$REPO" || exit 2
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
report "# T-0076-AC3: two throwaway dashboard modules" "" "HEAD \`$(git rev-parse --short HEAD)\`" ""
for mod in zz_db_a zz_db_b; do
  PROBE=feature/zz_probe/$mod
  report "## $mod"
  mkdir -p "$PROBE"
  cp -R "tool/mcgen/test/fixtures/$mod/." "$PROBE/"
  # The owned files are stored as *.fixture so that no analyzer, formatter or
  # Bazel package sees them in the fixtures directory.
  while IFS= read -r f; do mv "$f" "${f%.fixture}"; done < <(find "$PROBE" -name '*.fixture')
  step "mcgen gen $mod" "${DART[@]}" run tool/mcgen/bin/mcgen.dart gen "$mod"
  report "  - $(find "$PROBE" -type f | wc -l | tr -d ' ') files after generation"
  step "mcgen gen --check $mod (idempotent)" "${DART[@]}" run tool/mcgen/bin/mcgen.dart gen --check "$mod"
done
for mod in zz_db_a zz_db_b; do
  PROBE=feature/zz_probe/$mod
  step "bazel build --config=lint //$PROBE/... (mc_analysis, no issue)" bzw build --config=lint "//$PROBE/..."
done
for mod in zz_db_a zz_db_b; do
  PROBE=feature/zz_probe/$mod
  step "bazel test //$PROBE/... (uncached)" bzw test --nocache_test_results --test_output=errors "//$PROBE/..."
  if [[ -f "bazel-testlogs/$PROBE/bdd_test/test.log" ]]; then
    report "  - BDD scenarios: $(grep -c '^  PASS ' "bazel-testlogs/$PROBE/bdd_test/test.log") passed, $(grep -c '^  FAIL ' "bazel-testlogs/$PROBE/bdd_test/test.log") failed"
  fi
  for t in architecture_test bdd_test contract_test flow_scope_test; do
    [[ "$mod" == zz_db_a && "$t" == flow_scope_test ]] && continue
    if plain "$log" | grep -q "//$PROBE:$t .*PASSED"; then
      report "  - //$PROBE:$t PASSED"
    else
      report "  - **//$PROBE:$t not PASSED**"
      rc=1
    fi
  done
done
finish T-0076-AC3 "$rc"
