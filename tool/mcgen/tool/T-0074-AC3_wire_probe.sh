#!/bin/bash
# T-0074-AC3 (P2-08 AC1): given one new list-detail spec, `mcgen gen`, `mcgen
# wire` and `mcgen buildgen` alone make it part of the app. In a temp copy of
# the checkout (never the checkout itself):
#   1. copy every tracked (and untracked, not ignored) file; add the spec
#      tool/mcgen/test/fixtures/zz_ld_probe/mcgen.yaml as
#      feature/zz_probe/zz_ld_probe/mcgen.yaml. Nothing else is written by
#      hand: every other change in the copy is mcgen's (step 6 lists them);
#   2. mcgen gen zz_ld_probe, then mcgen wire, then mcgen buildgen;
#   3. the same three with --check: up to date (idempotent);
#   4. bazel build --config=sim //app/mini_client:mini_client_ios;
#   5. bazel test //... (the generated module, its generated wiring group,
#      and //app/mini_client:catalogue_test, which opens the new flow from
#      /catalogue);
#   6. every file that differs between the checkout and the copy, by tool;
#   and deletes the copy and shuts its Bazel server down, whatever happens.
#   tool/mcgen/tool/T-0074-AC3_wire_probe.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../checks/lib.sh"
cd "$REPO" || exit 2
read -r -a DART <<< "${MC_DART:-fvm dart}"
role="${ROLE:-engineer}"
COPY="$(mktemp -d "/tmp/mc-T-0074-probe-$role-XXXXXX")"
OB="/tmp/mc-ob-T-0074-ac3-$role"
log="$(mktemp)"
cleanup() {
  (cd "$COPY" 2>/dev/null && "$REPO/tool/bazelw" --output_base="$OB" shutdown >/dev/null 2>&1)
  rm -rf "$COPY" "$log"
}
trap cleanup EXIT
rc=0
step() {  # step <label> <command...>
  local label="$1"; shift
  if "$@" > "$log" 2>&1; then
    report "- PASS: $label"
  else
    report "- **FAIL**: $label" '```' "$(plain "$log" | tail -40)" '```'
    rc=1
  fi
}
mcg() { "${DART[@]}" run "$REPO/tool/mcgen/bin/mcgen.dart" "$@" --root "$COPY"; }
cbz() { (cd "$COPY" && "$REPO/tool/bazelw" --output_base="$OB" "$@"); }

report "# T-0074-AC3: a new list-detail spec, wired by mcgen alone" "" \
  "HEAD \`$(git rev-parse --short HEAD)\`, copy \`$COPY\` (deleted afterwards)" ""
# Tracked and untracked files, minus deleted ones (macOS rsync has no
# --ignore-missing-args).
git ls-files -co --exclude-standard -z \
  | python3 -I -c 'import os, sys; sys.stdout.buffer.write(b"\0".join(n for n in sys.stdin.buffer.read().split(b"\0") if n and os.path.lexists(n)))' \
  | rsync -a --from0 --files-from=- ./ "$COPY/"
PROBE=feature/zz_probe/zz_ld_probe
mkdir -p "$COPY/$PROBE"
cp tool/mcgen/test/fixtures/zz_ld_probe/mcgen.yaml "$COPY/$PROBE/mcgen.yaml"
report "- the copy: $(cd "$COPY" && find . -type f | wc -l | tr -d ' ') files; the one hand-written addition: \`$PROBE/mcgen.yaml\`"
before="$(mktemp)"
(cd "$COPY" && find . -type f -not -path './bazel-*' -exec shasum {} + | sort -k2) > "$before"

step "mcgen gen zz_ld_probe" mcg gen zz_ld_probe
step "mcgen wire" mcg wire
step "mcgen buildgen" mcg buildgen
plain "$log" | tail -1 | sed 's/^/  - /' >> "$REPORT"
step "mcgen gen --check zz_ld_probe (idempotent)" mcg gen --check zz_ld_probe
step "mcgen wire --check (idempotent)" mcg wire --check
step "mcgen buildgen --check (idempotent)" mcg buildgen --check

report "" "## Files mcgen wrote in the copy" "" '```'
(cd "$COPY" && find . -type f -not -path './bazel-*' -exec shasum {} + | sort -k2) \
  | diff "$before" - | sed -n 's/^> [0-9a-f]* *\.\///p' | sort -u >> "$REPORT"
report '```' ""
rm -f "$before"

step "bazel build --config=sim //app/mini_client:mini_client_ios" \
  cbz build --config=sim //app/mini_client:mini_client_ios
step "bazel test --lockfile_mode=error //..." \
  cbz test --lockfile_mode=error --test_output=errors //...
results="$(plain "$log")"
grep -E "Executed [0-9]+ out of" <<< "$results" | sed 's/^/  - /' >> "$REPORT"
# Not `plain | grep -q`: grep -q exits at the first match, and under
# pipefail the SIGPIPE of the writer fails the test.
for t in //feature/zz_probe/zz_ld_probe:bdd_test //feature/zz_probe/zz_ld_probe:architecture_test \
         //feature/zz_probe/zz_ld_probe:flow_scope_test //app/wiring/zz_probe_wiring:routes_test \
         //app/mini_client:catalogue_test //app/mini_client:analytics_screens_test; do
  if grep -E "^$t +(\(cached\) )?PASSED" <<< "$results" > /dev/null; then
    report "  - $t PASSED"
  else
    report "  - **$t not PASSED**"
    rc=1
  fi
done
if [[ -f "$COPY/bazel-testlogs/app/mini_client/catalogue_test/test.log" ]]; then
  report "" "## //app/mini_client:catalogue_test in the copy" "" '```'
  grep -E "T-0074-AC3|All tests passed|Some tests failed" \
    "$COPY/bazel-testlogs/app/mini_client/catalogue_test/test.log" | head -20 >> "$REPORT"
  report '```'
fi
finish T-0074-AC3 "$rc"
