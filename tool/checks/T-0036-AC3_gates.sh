#!/bin/bash
# T-0036-AC3: one check that fails when any of these fails.
#   1. the gates (T-0035-AC4_gates.sh: test //... with the touched packages
#      uncached, lint, mc_arch_check, rules_fork.sh check, format, l10n_check,
#      flow_builder provenance, coverage >= 90 %);
#   2. the T-0032 byte-identity and cutoff checks;
#   3. no `flowLeading` in code (everything but documents/ and tool/checks);
#   4. the stale comments are gone (feature_flow.dart's old doc sentences,
#      "assertion above", "skipped until T-0035");
#   5. the mutation scripts (T-0033's and T-0037's, which carries T-0036's
#      mutations re-expressed for the T-0037 widget): every mutation killed by
#      a test. A file that check 4 greps and that is missing fails the check
#      (T-0037-AC4).
#   tool/checks/T-0036-AC3_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP defaults to --output_base=/tmp/mc-ob-T-0036-<role>.
# MC_GREP_ROOT (tests of this script only) points the greps at another tree;
# MC_ONLY_GREPS=1 skips the long gates, to show a negative quickly.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
export MC_BAZEL_STARTUP="${MC_BAZEL_STARTUP:---output_base=/tmp/mc-ob-T-0036-$ROLE}"
export MC_TASK=T-0036 MC_ROLE="$ROLE"
GREP_ROOT="${MC_GREP_ROOT:-$REPO}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
rows=(); fails=(); ok=1
gate() {  # gate <name> <command...>
  local name="$1"; shift
  local log="$work/$(tr -c 'a-zA-Z0-9' _ <<< "$name").log"
  if "$@" > "$log" 2>&1; then rows+=("| $name | PASS |")
  else
    rows+=("| $name | **FAIL** |"); ok=0
    fails+=("" "### $name failed" "" '```' "$(plain "$log" | grep -a -v '^\[' | tail -25)" '```')
  fi
}
no_flow_leading() {
  local hits
  hits=$(grep -rIn --exclude-dir=.git --exclude-dir=documents --exclude-dir='bazel-*' \
    --exclude-dir=.dart_tool --exclude-dir=tool 'flowLeading' "$GREP_ROOT" || true)
  [[ -z "$hits" ]] || { echo "flowLeading still used:"; echo "$hits"; return 1; }
}
no_stale_comments() {
  local hits="" f
  # stale <file> <fixed-string> <what>: a file that is missing is a failure
  # (a moved or renamed file must not silently pass the check).
  stale() {
    if [[ ! -f "$1" ]]; then hits+="$1: MISSING (cannot check '$3')"$'\n'
    elif grep -qF -- "$2" "$1"; then hits+="${1#$GREP_ROOT/}: $3"$'\n'; fi
  }
  f="$GREP_ROOT/utility/mc_feature_flow/lib/src/feature_flow.dart"
  stale "$f" "flow adds the core strings and Flutter's own after them" "old doc sentence"
  stale "$f" 'Empty: the flow leaves `Localizations` as the host set it.' "stale 'Empty:' line"
  stale "$GREP_ROOT/utility/mc_api_client/test/api_client_test.dart" 'assertion above' "'assertion above'"
  stale "$GREP_ROOT/app/mini_client/BUILD.bazel" 'skipped until T-0035' "'skipped until T-0035'"
  [[ -z "$hits" ]] || { echo "stale comments:"; echo "$hits"; return 1; }
}
mutations() {
  # Both scripts use the gates' own Bazel output base.
  export MC_OB="${MC_BAZEL_STARTUP#--output_base=}"
  documents/evidence/T-0033/engineer/mutations.sh &&
    MC_TASK=T-0037 MC_ROLE="$ROLE" documents/evidence/T-0037/engineer/mutations.sh
}
if [[ -z "${MC_ONLY_GREPS:-}" ]]; then
  gate "gates (T-0035-AC4_gates.sh)" tool/checks/T-0035-AC4_gates.sh --role "$ROLE"
  gate "T-0032 byte identity" tool/checks/T-0032-AC6_matches_build_runner.sh --role "$ROLE"
  gate "T-0032 cutoff" tool/checks/T-0032-AC6_cutoff.sh --role "$ROLE"
  gate "mutation scripts (every mutation killed by a test)" mutations
fi
gate "no flowLeading in code" no_flow_leading
gate "stale comments fixed" no_stale_comments
report "# T-0036-AC3: gates, greps and mutations" "" "| Gate | Result |" "|---|---|" "${rows[@]}" \
  ${fails[@]+"${fails[@]}"}
finish T-0036-AC3-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
