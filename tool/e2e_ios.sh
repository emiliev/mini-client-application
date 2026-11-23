#!/usr/bin/env bash
# tool/e2e_ios.sh: run a Flutter project's e2e tests on a freshly created,
# private iOS simulator, collect screenshots and logs as evidence, and always
# delete the simulator afterwards.
#
# Spec: documents/tasks/T-0012-ios-sim-e2e-runner.md
# Background: documents/findings/F-0004-ios-verification-pipeline.md, ADR-0006
# Usage: tool/e2e_ios.sh --help   (see also tool/README.md)
#
# Must run on macOS /bin/bash 3.2: no associative arrays, no mapfile, and
# empty arrays are never expanded under `set -u`.

set -euo pipefail

E2E_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E2E_REPO_ROOT="$(cd "$E2E_SCRIPT_DIR/.." && pwd)"
E2E_MAX_HEIGHT=1200
E2E_PY=/usr/bin/python3

DEFAULT_DEVICE="iPhone 17 Pro"
DEFAULT_RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
DEFAULT_DRIVER="test_driver/integration_test.dart"
DEFAULT_RUNNER_CMD='fvm flutter drive --driver={driver} --target={target} -d {udid}'

usage() {
  cat <<'EOF'
Usage: tool/e2e_ios.sh --task T-XXXX --role engineer|verifier --project <flutter-project-dir>
                       [--target integration_test/<file>.dart]...
                       [--driver test_driver/integration_test.dart]
                       [--device "iPhone 17 Pro"]
                       [--runtime com.apple.CoreSimulator.SimRuntime.iOS-26-2]
                       [--evidence-dir <dir>]
                       [--runner-cmd "<cmd using {target} {driver} {udid}>"]
                       [--keep-sim]

Creates a private simulator named mc-<task>-<role>-<pid>, boots it, runs every
target with SCREENSHOT_DIR exported to a per-target temp dir, copies the
screenshots (downscaled only if taller than 1200 px) and per-target logs into
the evidence dir, writes e2e-summary.md there, and deletes the simulator on
exit, error, SIGINT or SIGTERM (unless --keep-sim).

Defaults:
  --target       every integration_test/*_test.dart in the project
  --driver       test_driver/integration_test.dart
  --device       iPhone 17 Pro
  --runtime      com.apple.CoreSimulator.SimRuntime.iOS-26-2
  --evidence-dir <repo>/documents/evidence/<task>
  --runner-cmd   fvm flutter drive --driver={driver} --target={target} -d {udid}
                 (run from --project; placeholders are replaced shell-quoted)

Exit codes: 0 all targets passed; 1 a target failed; 2 bad arguments or failed
pre-flight (no simulator was created); 3 simulator setup failed;
130 / 143 interrupted by SIGINT / SIGTERM.
EOF
}

log() { printf '==> %s\n' "$*"; }
warn() { printf 'e2e_ios: warning: %s\n' "$*" >&2; }
die() { printf 'e2e_ios: error: %s\n' "$*" >&2; exit 2; }

# replace_all <string> <from> <to>: literal (non-pattern) replacement that
# behaves the same on bash 3.2 and 5.x (no patsub_replacement surprises).
replace_all() {
  local s=$1 from=$2 to=$3 out=""
  while :; do
    case $s in
      *"$from"*)
        out=$out${s%%"$from"*}$to
        s=${s#*"$from"}
        ;;
      *) break ;;
    esac
  done
  printf '%s' "$out$s"
}

# png_dims <file>: prints "<width> <height>", or nothing if sips can't read it.
png_dims() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null |
    awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{if (w != "" && h != "") print w, h}'
}

# downscale_if_tall <src.png> <dst.png>
# Copies src to dst byte-for-byte when it is at most E2E_MAX_HEIGHT px tall;
# otherwise writes a copy resampled with `sips -Z` so it fits in 1200 px.
# `sips -Z` alone would also enlarge small images (F-0004 gotcha 11).
# Prints a note for the summary: "unchanged WxH" or "downscaled from WxH".
# Returns 1 (and prints nothing on stdout) if dst could not be written.
# Every step is checked explicitly: callers use it in `if note=$(...)`, where
# `set -e` is off.
downscale_if_tall() {
  local src=$1 dst=$2 dims w h
  dims=$(png_dims "$src")
  if [ -z "$dims" ]; then
    printf 'e2e_ios: error: cannot read image size of %s\n' "$src" >&2
    return 1
  fi
  w=${dims% *}
  h=${dims#* }
  if [ "$h" -gt "$E2E_MAX_HEIGHT" ]; then
    if ! sips -Z "$E2E_MAX_HEIGHT" "$src" --out "$dst" >/dev/null 2>&1; then
      printf 'e2e_ios: error: sips could not write %s\n' "$dst" >&2
      return 1
    fi
    if [ -z "$(png_dims "$dst")" ]; then
      printf 'e2e_ios: error: %s is missing or unreadable after sips\n' "$dst" >&2
      return 1
    fi
    printf 'downscaled from %sx%s\n' "$w" "$h"
  else
    if ! cp "$src" "$dst"; then
      printf 'e2e_ios: error: could not copy %s to %s\n' "$src" "$dst" >&2
      return 1
    fi
    printf 'unchanged %sx%s\n' "$w" "$h"
  fi
}

# simctl_devices_tsv: one line per simulator in the default device set:
# "<udid>\t<state>\t<name>".
simctl_devices_tsv() {
  xcrun simctl list devices -j | "$E2E_PY" -I -c '
import json, sys
data = json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for d in devices:
        print("%s\t%s\t%s" % (d.get("udid", ""), d.get("state", ""), d.get("name", "")))
'
}

# udids_named <name>: UDIDs of simulators whose name is exactly <name>.
udids_named() {
  simctl_devices_tsv | awk -F '\t' -v n="$1" '$3 == n { print $1 }'
}

# descendants <pid>: all descendant pids, depth first.
descendants() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null || true); do
    echo "$child"
    descendants "$child"
  done
}

# kill_tree <pid>: TERM the process and all its descendants, KILL after 5 s.
kill_tree() {
  local root=$1 pids i
  pids="$root $(descendants "$root" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  kill -TERM $pids 2>/dev/null || true
  i=0
  while [ "$i" -lt 50 ]; do
    local alive=0 p
    for p in $pids; do
      if kill -0 "$p" 2>/dev/null; then alive=1; break; fi
    done
    [ "$alive" -eq 0 ] && return 0
    sleep 0.1
    i=$((i + 1))
  done
  # shellcheck disable=SC2086
  kill -KILL $pids 2>/dev/null || true
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ---------------------------------------------------------------- state ----
TASK=""
ROLE=""
PROJECT_DIR=""
TARGETS=()
DRIVER="$DEFAULT_DRIVER"
DEVICE="$DEFAULT_DEVICE"
RUNTIME="$DEFAULT_RUNTIME"
EVIDENCE_DIR=""
RUNNER_CMD_TEMPLATE="$DEFAULT_RUNNER_CMD"
KEEP_SIM=0

DEVICE_TYPE_ID=""
RUNTIME_NAME=""
SIM_NAME=""
SIM_UDID=""
SIM_CREATE_STARTED=0
WORK_TMP=""
CHILD_PID=""
STARTED_AT=""
SUMMARY_FINAL=0
SIGNAL_NAME=""
CURRENT_IDX=-1

T_RESULTS=()
T_DURATIONS=()
T_LOGS=()
S_FILES=()
S_NOTES=()
S_TARGETS=()

# ------------------------------------------------------------- summary -----
write_summary() {
  local overall=$1 f tmp i n
  [ -n "$EVIDENCE_DIR" ] && [ -d "$EVIDENCE_DIR" ] || return 0
  f="$EVIDENCE_DIR/e2e-summary.md"
  tmp="$f.tmp.$$"
  n=${#TARGETS[@]}
  {
    echo "# E2E summary: $TASK ($ROLE)"
    echo
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Result | **$overall** |"
    echo "| Task | $TASK |"
    echo "| Role | $ROLE |"
    echo "| Project | \`$PROJECT_DIR\` |"
    echo "| Device | $DEVICE (\`$DEVICE_TYPE_ID\`) |"
    echo "| Runtime | $RUNTIME_NAME (\`$RUNTIME\`) |"
    echo "| Simulator | \`$SIM_NAME\` |"
    echo "| Simulator UDID | \`${SIM_UDID:-n/a}\` |"
    echo "| Runner | \`$(replace_all "$RUNNER_CMD_TEMPLATE" '|' '\|')\` |"
    echo "| Started | $STARTED_AT |"
    echo "| Finished | $(now_utc) |"
    echo
    echo "## Targets"
    echo
    echo "| Target | Result | Duration | Log |"
    echo "|---|---|---|---|"
    i=0
    while [ "$i" -lt "$n" ]; do
      if [ "$i" -lt "${#T_RESULTS[@]}" ]; then
        echo "| \`${TARGETS[$i]}\` | ${T_RESULTS[$i]} | ${T_DURATIONS[$i]} s | [${T_LOGS[$i]}](${T_LOGS[$i]}) |"
      elif [ "$i" -eq "$CURRENT_IDX" ]; then
        echo "| \`${TARGETS[$i]}\` | INTERRUPTED | - | - |"
      else
        echo "| \`${TARGETS[$i]}\` | NOT RUN | - | - |"
      fi
      i=$((i + 1))
    done
    echo
    echo "## Screenshots"
    echo
    if [ "${#S_FILES[@]}" -eq 0 ]; then
      echo "_None._"
    else
      echo "| File | Target | Note |"
      echo "|---|---|---|"
      i=0
      while [ "$i" -lt "${#S_FILES[@]}" ]; do
        echo "| [${S_FILES[$i]}](${S_FILES[$i]}) | \`${S_TARGETS[$i]}\` | ${S_NOTES[$i]} |"
        i=$((i + 1))
      done
    fi
  } >"$tmp"
  mv "$tmp" "$f"
}

# ------------------------------------------------------------- teardown ----
cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  set +e

  if [ -n "$CHILD_PID" ] && kill -0 "$CHILD_PID" 2>/dev/null; then
    log "Stopping runner (pid $CHILD_PID) and its child processes"
    # stderr off: hides bash's "Terminated: 15" job notice for the child.
    {
      kill_tree "$CHILD_PID"
      wait "$CHILD_PID"
    } 2>/dev/null
  fi
  CHILD_PID=""

  if [ "$SIM_CREATE_STARTED" -eq 1 ]; then
    if [ "$KEEP_SIM" -eq 1 ]; then
      log "Keeping simulator $SIM_NAME (${SIM_UDID:-unknown UDID}) because of --keep-sim"
      log "Delete it later with: xcrun simctl shutdown ${SIM_UDID:-<udid>}; xcrun simctl delete ${SIM_UDID:-<udid>}"
    else
      # Look the device up by its unique name too, in case a signal arrived
      # between `simctl create` returning and SIM_UDID being assigned.
      local udids u
      udids=$( { [ -n "$SIM_UDID" ] && echo "$SIM_UDID"; udids_named "$SIM_NAME"; } | sort -u)
      for u in $udids; do
        xcrun simctl shutdown "$u" >/dev/null 2>&1
        if xcrun simctl delete "$u" >/dev/null 2>&1; then
          log "Deleted simulator $SIM_NAME ($u)"
        fi
      done
      if [ -n "$(udids_named "$SIM_NAME")" ]; then
        warn "simulator $SIM_NAME still exists; run tool/sim_cleanup.sh"
        [ "$rc" -eq 0 ] && rc=3
      fi
      printf 'SIMULATOR_DELETED_AT=%s\n' "$(date +%s)"
    fi
  fi

  if [ "$SUMMARY_FINAL" -eq 0 ] && [ "$SIM_CREATE_STARTED" -eq 1 ]; then
    if [ -n "$SIGNAL_NAME" ]; then
      write_summary "INTERRUPTED (SIG$SIGNAL_NAME)"
    else
      write_summary "ERROR (exit $rc)"
    fi
    [ -f "$EVIDENCE_DIR/e2e-summary.md" ] && log "Summary: $EVIDENCE_DIR/e2e-summary.md"
  fi

  [ -n "$WORK_TMP" ] && rm -rf "$WORK_TMP"
  exit "$rc"
}

on_signal() {
  SIGNAL_NAME=$1
  printf 'e2e_ios: received SIG%s, cleaning up\n' "$1" >&2
  if [ "$1" = "INT" ]; then exit 130; else exit 143; fi
}

# ------------------------------------------------------------ pre-flight ---
parse_args() {
  while [ $# -gt 0 ]; do
    case $1 in
      --task | --role | --project | --target | --driver | --device | --runtime | --evidence-dir | --runner-cmd)
        [ $# -ge 2 ] || die "$1 needs a value"
        case $1 in
          --task) TASK=$2 ;;
          --role) ROLE=$2 ;;
          --project) PROJECT_DIR=$2 ;;
          --target) TARGETS+=("$2") ;;
          --driver) DRIVER=$2 ;;
          --device) DEVICE=$2 ;;
          --runtime) RUNTIME=$2 ;;
          --evidence-dir) EVIDENCE_DIR=$2 ;;
          --runner-cmd) RUNNER_CMD_TEMPLATE=$2 ;;
        esac
        shift 2
        ;;
      --keep-sim) KEEP_SIM=1; shift ;;
      -h | --help) usage; exit 0 ;;
      *) usage >&2; die "unknown argument '$1'" ;;
    esac
  done

  [ -n "$TASK" ] || die "--task is required (e.g. --task T-0012)"
  [[ $TASK =~ ^T-[0-9]{4}$ ]] || die "--task '$TASK' must look like T-0012"
  case $ROLE in
    engineer | verifier) ;;
    "") die "--role is required (engineer or verifier)" ;;
    *) die "--role '$ROLE' must be engineer or verifier" ;;
  esac
  [ -n "$PROJECT_DIR" ] || die "--project is required"
  [ -n "$RUNNER_CMD_TEMPLATE" ] || die "--runner-cmd must not be empty"
}

preflight_tools() {
  local tool
  for tool in xcrun fvm sips; do
    command -v "$tool" >/dev/null 2>&1 || die "'$tool' not found on PATH"
  done
  [ -x "$E2E_PY" ] || die "$E2E_PY not found (needed to parse simctl JSON)"
  xcrun --find simctl >/dev/null 2>&1 || die "'xcrun simctl' is not available (install Xcode)"
}

preflight_project() {
  [ -d "$PROJECT_DIR" ] || die "--project '$PROJECT_DIR' is not a directory"
  PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
  [ -f "$PROJECT_DIR/pubspec.yaml" ] || die "--project '$PROJECT_DIR' has no pubspec.yaml"

  if [ "${#TARGETS[@]}" -eq 0 ]; then
    local f
    for f in "$PROJECT_DIR"/integration_test/*_test.dart; do
      [ -e "$f" ] || continue
      TARGETS+=("integration_test/$(basename "$f")")
    done
    [ "${#TARGETS[@]}" -gt 0 ] || die "no integration_test/*_test.dart in '$PROJECT_DIR' (pass --target)"
  fi
  local i=0
  while [ "$i" -lt "${#TARGETS[@]}" ]; do
    [ -f "$PROJECT_DIR/${TARGETS[$i]}" ] || die "--target '${TARGETS[$i]}' not found in '$PROJECT_DIR'"
    i=$((i + 1))
  done
  case $RUNNER_CMD_TEMPLATE in
    *"{driver}"*)
      [ -f "$PROJECT_DIR/$DRIVER" ] || die "--driver '$DRIVER' not found in '$PROJECT_DIR'"
      ;;
  esac
}

# Checks the runtime and device type exist, are available, and fit together.
preflight_simulator() {
  local json verdict
  json=$(xcrun simctl list -j devicetypes runtimes 2>/dev/null) ||
    json=$(xcrun simctl list -j) ||
    die "'xcrun simctl list -j' failed"
  verdict=$(printf '%s' "$json" | "$E2E_PY" -I -c '
import json, sys
data = json.load(sys.stdin)
runtime, device = sys.argv[1], sys.argv[2]
runtimes = data.get("runtimes", [])
rt = next((r for r in runtimes if r.get("identifier") == runtime), None)
if rt is None or not rt.get("isAvailable", False):
    avail = ", ".join(r.get("identifier", "?") for r in runtimes
                      if r.get("isAvailable") and r.get("platform", "iOS") == "iOS")
    print("ERR\tunknown or unavailable --runtime \x27%s\x27 (available iOS runtimes: %s)"
          % (runtime, avail or "none"))
    sys.exit(0)
types = data.get("devicetypes", [])
dt = next((d for d in types if device in (d.get("name"), d.get("identifier"))), None)
if dt is None:
    print("ERR\tunknown --device \x27%s\x27 (list them with: xcrun simctl list devicetypes)" % device)
    sys.exit(0)
supported = rt.get("supportedDeviceTypes")
if supported is not None and not any(s.get("identifier") == dt.get("identifier") for s in supported):
    print("ERR\t--device \x27%s\x27 is not supported by --runtime \x27%s\x27" % (device, runtime))
    sys.exit(0)
print("OK\t%s\t%s" % (dt.get("identifier"), rt.get("name", runtime)))
' "$RUNTIME" "$DEVICE")
  case $verdict in
    OK*)
      DEVICE_TYPE_ID=$(printf '%s' "$verdict" | cut -f2)
      RUNTIME_NAME=$(printf '%s' "$verdict" | cut -f3)
      ;;
    ERR*) die "$(printf '%s' "$verdict" | cut -f2-)" ;;
    *) die "could not check --runtime '$RUNTIME' / --device '$DEVICE'" ;;
  esac

  SIM_NAME="mc-$TASK-$ROLE-$$"
  if [ -n "$(udids_named "$SIM_NAME")" ]; then
    die "a simulator named $SIM_NAME already exists (an orphan from a dead run?); run tool/sim_cleanup.sh"
  fi
}

# --------------------------------------------------------------- running ---
render_cmd() {
  local target=$1 cmd=$RUNNER_CMD_TEMPLATE
  cmd=$(replace_all "$cmd" "{target}" "$(printf '%q' "$target")")
  cmd=$(replace_all "$cmd" "{driver}" "$(printf '%q' "$DRIVER")")
  cmd=$(replace_all "$cmd" "{udid}" "$(printf '%q' "$SIM_UDID")")
  printf '%s' "$cmd"
}

# run_child <logfile> <cmd...>
# Runs a command in the background, appending its output to <logfile>, and
# waits for it, so that SIGINT/SIGTERM sent to this script are handled
# immediately (bash defers traps until a foreground child exits) and the trap
# can kill the child's process tree (F-0005).
# The redirection must stay on the background command: redirecting the
# run_child call itself would also redirect the trap's output into <logfile>.
run_child() {
  local logfile=$1
  shift
  "$@" >>"$logfile" 2>&1 </dev/null &
  CHILD_PID=$!
  local rc=0
  wait "$CHILD_PID" || rc=$?
  CHILD_PID=""
  return "$rc"
}

create_and_boot() {
  log "Creating simulator $SIM_NAME ($DEVICE, $RUNTIME_NAME)"
  printf 'SIMULATOR_NAME=%s\n' "$SIM_NAME"
  SIM_CREATE_STARTED=1
  if ! SIM_UDID=$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE_ID" "$RUNTIME"); then
    printf 'e2e_ios: error: xcrun simctl create failed\n' >&2
    exit 3
  fi
  printf 'SIMULATOR_UDID=%s\n' "$SIM_UDID"
  printf 'SIMULATOR_CREATED_AT=%s\n' "$(date +%s)"

  log "Booting $SIM_UDID"
  local boot_log="$WORK_TMP/boot.log" t0
  t0=$(date +%s)
  if ! xcrun simctl boot "$SIM_UDID" >"$boot_log" 2>&1; then
    cat "$boot_log" >&2
    printf 'e2e_ios: error: xcrun simctl boot failed\n' >&2
    exit 3
  fi
  if ! run_child "$boot_log" xcrun simctl bootstatus "$SIM_UDID" -b; then
    tail -n 20 "$boot_log" >&2
    printf 'e2e_ios: error: xcrun simctl bootstatus failed\n' >&2
    exit 3
  fi
  log "Booted in $(($(date +%s) - t0)) s"
}

# collect_screenshots <shot-dir> <target>
collect_screenshots() {
  local dir=$1 target=$2 f name dst note stem j clash
  stem=$(basename "$target")
  stem=${stem%.dart}
  for f in "$dir"/*.png; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    clash=0
    j=0
    while [ "$j" -lt "${#S_FILES[@]}" ]; do
      [ "${S_FILES[$j]}" = "$name" ] && clash=1
      j=$((j + 1))
    done
    if [ "$clash" -eq 1 ]; then
      warn "screenshot $name from $target clashes with an earlier target; saving as $stem-$name"
      name="$stem-$name"
    fi
    dst="$EVIDENCE_DIR/$name"
    if note=$(downscale_if_tall "$f" "$dst"); then
      S_FILES+=("$name")
      S_NOTES+=("$note")
      S_TARGETS+=("$target")
      log "  screenshot $name ($note)"
    else
      warn "could not process screenshot $f"
    fi
  done
}

# run_target <index>: returns 0 on PASS, 1 on FAIL.
run_target() {
  local idx=$1 target=${TARGETS[$1]} stem logname logfile shots cmd t0 rc j
  stem=$(basename "$target")
  stem=${stem%.dart}
  logname="e2e-$stem.log"
  j=0
  while [ "$j" -lt "${#T_LOGS[@]}" ]; do
    [ "${T_LOGS[$j]}" = "$logname" ] && logname="e2e-$stem-$((idx + 1)).log"
    j=$((j + 1))
  done
  logfile="$EVIDENCE_DIR/$logname"
  shots="$WORK_TMP/screenshots/$((idx + 1))-$stem"
  mkdir -p "$shots"
  cmd=$(render_cmd "$target")

  CURRENT_IDX=$idx
  log "Running target $((idx + 1))/${#TARGETS[@]}: $target"
  log "  \$ $cmd"
  log "  log: $logfile"
  {
    echo "# e2e_ios.sh: $TASK $ROLE on $SIM_NAME ($SIM_UDID)"
    echo "# cwd: $PROJECT_DIR"
    echo "# SCREENSHOT_DIR=$shots"
    echo "\$ $cmd"
    echo
  } >"$logfile"

  t0=$(date +%s)
  rc=0
  run_child "$logfile" /bin/bash -c "cd \"\$1\" && SCREENSHOT_DIR=\"\$2\" exec /bin/bash -c \"\$3\"" \
    e2e-runner "$PROJECT_DIR" "$shots" "$cmd" || rc=$?
  local dur=$(($(date +%s) - t0))
  printf '\n# exit code: %s\n' "$rc" >>"$logfile"

  collect_screenshots "$shots" "$target"
  T_DURATIONS+=("$dur")
  T_LOGS+=("$logname")
  if [ "$rc" -eq 0 ]; then
    T_RESULTS+=("PASS")
    log "PASS $target (${dur} s)"
  else
    T_RESULTS+=("FAIL")
    log "FAIL $target (${dur} s, exit $rc). Last lines of $logname:"
    tail -n 30 "$logfile" | sed 's/^/    /' >&2
  fi
  CURRENT_IDX=-1
  write_summary "RUNNING"
  [ "$rc" -eq 0 ]
}

main() {
  parse_args "$@"
  preflight_tools
  preflight_project
  preflight_simulator

  [ -n "$EVIDENCE_DIR" ] || EVIDENCE_DIR="$E2E_REPO_ROOT/documents/evidence/$TASK"
  mkdir -p "$EVIDENCE_DIR"
  EVIDENCE_DIR=$(cd "$EVIDENCE_DIR" && pwd)
  WORK_TMP=$(mktemp -d "${TMPDIR:-/tmp}/e2e_ios.XXXXXX")
  STARTED_AT=$(now_utc)

  trap cleanup EXIT
  trap 'on_signal INT' INT
  trap 'on_signal TERM' TERM

  log "Task $TASK, role $ROLE, project $PROJECT_DIR"
  log "Evidence dir: $EVIDENCE_DIR"
  create_and_boot

  local i=0 failed=0
  while [ "$i" -lt "${#TARGETS[@]}" ]; do
    run_target "$i" || failed=$((failed + 1))
    i=$((i + 1))
  done

  if [ "$failed" -eq 0 ]; then
    write_summary "PASS"
  else
    write_summary "FAIL"
  fi
  SUMMARY_FINAL=1
  log "Summary: $EVIDENCE_DIR/e2e-summary.md"
  if [ "$failed" -eq 0 ]; then
    log "RESULT: PASS (${#TARGETS[@]} target(s))"
    exit 0
  fi
  log "RESULT: FAIL ($failed of ${#TARGETS[@]} target(s) failed)"
  exit 1
}

# Only run when executed, so the test suite can `source` this file and call
# downscale_if_tall directly (T-0012-AC7).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
