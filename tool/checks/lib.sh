# Shared helpers for tool/checks/T-XXXX-ACn_*.sh (sourced, not run).
# Each check derives the repo root from its own location, so it works in any
# worktree, prints a Markdown report, exits 0 for PASS and 1 for FAIL, and
# with `--out FILE` also writes the report to FILE.

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
BAZELW="$REPO/tool/bazelw"
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
ROLE="${ROLE:-engineer}"
REPORT="$(mktemp)"
report() { printf '%s\n' "$@" >> "$REPORT"; }
finish() {  # finish <check-id> <0|1>
  if [[ "$2" == 0 ]]; then report "" "**PASS $1**"; else report "" "**FAIL $1**"; fi
  cat "$REPORT"
  if [[ -n "$OUT" ]]; then mkdir -p "$(dirname "$OUT")"; cp "$REPORT" "$OUT"; fi
  rm -f "$REPORT"
  exit "$2"
}
# Strip Bazel's curses progress so logs can be grepped.
plain() { tr '\r' '\n' < "$1"; }
