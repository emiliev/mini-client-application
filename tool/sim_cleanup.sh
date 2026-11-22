#!/usr/bin/env bash
# tool/sim_cleanup.sh: delete orphaned fleet simulators, i.e. every simulator
# whose name starts with "mc-" (left behind when tool/e2e_ios.sh was killed
# with SIGKILL and its trap could not run). Never touches any other simulator.
#
# Spec: documents/tasks/T-0012-ios-sim-e2e-runner.md (T-0012-AC6)
# Must run on macOS /bin/bash 3.2.

set -euo pipefail

PREFIX="mc-"
PY=/usr/bin/python3
DRY_RUN=0
DEVICE_SET=""

usage() {
  cat <<'EOF'
Usage: tool/sim_cleanup.sh [--dry-run] [--device-set <dir>]

Shuts down and deletes every simulator whose name starts with "mc-".
Simulators with any other name are never touched.

  --dry-run           list the simulators that would be deleted; delete nothing
  --device-set <dir>  work on a custom simctl device set (xcrun simctl --set <dir>)
                      instead of the default one; the test suite uses this so it
                      never deletes another agent's live mc- simulator

Warning: in the default device set this also deletes the simulator of an e2e
run that is still in progress. Only run it when no tool/e2e_ios.sh is running.

Exit codes: 0 done (or nothing to do); 1 a simulator could not be deleted;
2 bad arguments.
EOF
}

die() { printf 'sim_cleanup: error: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=1; shift ;;
    --device-set)
      [ $# -ge 2 ] || die "--device-set needs a directory"
      DEVICE_SET=$2
      shift 2
      ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument '$1'" ;;
  esac
done

if [ -n "$DEVICE_SET" ]; then
  [ -d "$DEVICE_SET" ] || die "--device-set '$DEVICE_SET' is not a directory"
fi
command -v xcrun >/dev/null 2>&1 || die "'xcrun' not found on PATH"
[ -x "$PY" ] || die "$PY not found (needed to parse simctl JSON)"

simctl() {
  if [ -n "$DEVICE_SET" ]; then
    xcrun simctl --set "$DEVICE_SET" "$@"
  else
    xcrun simctl "$@"
  fi
}

# "<udid>\t<state>\t<name>" for every simulator whose name starts with PREFIX.
list_fleet_sims() {
  simctl list devices -j | "$PY" -I -c '
import json, sys
prefix = sys.argv[1]
data = json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for d in devices:
        name = d.get("name", "")
        if name.startswith(prefix):
            print("%s\t%s\t%s" % (d.get("udid", ""), d.get("state", ""), name))
' "$PREFIX"
}

UDIDS=()
STATES=()
NAMES=()
while IFS="$(printf '\t')" read -r udid state name; do
  [ -n "$udid" ] || continue
  UDIDS+=("$udid")
  STATES+=("$state")
  NAMES+=("$name")
done < <(list_fleet_sims)

where="default device set"
[ -n "$DEVICE_SET" ] && where="device set $DEVICE_SET"

if [ "${#UDIDS[@]}" -eq 0 ]; then
  echo "No simulators named $PREFIX* in the $where."
  exit 0
fi

failed=0
i=0
while [ "$i" -lt "${#UDIDS[@]}" ]; do
  udid=${UDIDS[$i]}
  state=${STATES[$i]}
  name=${NAMES[$i]}
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would delete: $name ($udid) [$state]"
  else
    if [ "$state" != "Shutdown" ]; then
      simctl shutdown "$udid" >/dev/null 2>&1 || true
    fi
    if simctl delete "$udid" </dev/null; then
      echo "deleted: $name ($udid) [was $state]"
    else
      echo "FAILED to delete: $name ($udid) [$state]" >&2
      failed=$((failed + 1))
    fi
  fi
  i=$((i + 1))
done

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: ${#UDIDS[@]} simulator(s) named $PREFIX* in the $where; nothing deleted."
  exit 0
fi
echo "Deleted $((${#UDIDS[@]} - failed)) of ${#UDIDS[@]} simulator(s) named $PREFIX* in the $where."
[ "$failed" -eq 0 ]
