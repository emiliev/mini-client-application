#!/usr/bin/env bash
# tool/test/e2e_ios_test.sh: automated tests for tool/e2e_ios.sh and
# tool/sim_cleanup.sh, one test per acceptance criterion of T-0012.
#
#   tool/test/e2e_ios_test.sh            # run every test (about 5-8 min)
#   tool/test/e2e_ios_test.sh AC5 AC7    # run only tests whose name contains AC5 or AC7
#
# The suite builds a throwaway Flutter fixture app in a temp dir (nothing large
# is committed), runs the scripts under test with /bin/bash (3.2) by default,
# and deletes every simulator it created, even when a test fails or the suite
# is interrupted.
#
# Environment:
#   E2E_TEST_BASH     bash used to run the scripts under test (default /bin/bash)
#   E2E_TEST_DEVICE   device type (default "iPhone 17 Pro")
#   E2E_TEST_RUNTIME  runtime id (default com.apple.CoreSimulator.SimRuntime.iOS-26-2)
#   E2E_TEST_KEEP=1   keep the temp dir (fixtures, outputs, evidence) afterwards

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "$TEST_DIR/.." && pwd)"
E2E="$TOOL_DIR/e2e_ios.sh"
CLEANUP="$TOOL_DIR/sim_cleanup.sh"
BASH_BIN=${E2E_TEST_BASH:-/bin/bash}
DEVICE=${E2E_TEST_DEVICE:-iPhone 17 Pro}
RUNTIME=${E2E_TEST_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-2}
PY=/usr/bin/python3
TASK=T-0012
SUITE_PID=$$
TAB=$(printf '\t')

WORK=$(mktemp -d "${TMPDIR:-/tmp}/e2e_ios_test.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
OUT="$WORK/out"
EV="$WORK/evidence"
mkdir -p "$OUT" "$EV"
BG_PIDS_FILE="$WORK/bg-pids"
DEVSETS_FILE="$WORK/device-sets"
: >"$BG_PIDS_FILE"
: >"$DEVSETS_FILE"

FIX_BASE="$WORK/fixture_base"
FIX_PASS="$WORK/fixture_pass"
FIX_FAIL="$WORK/fixture_fail"
FIX_PAR_E="$WORK/fixture_par_engineer"
FIX_PAR_V="$WORK/fixture_par_verifier"
STUB="$WORK/stub_project"

# --------------------------------------------------------------- helpers ---
say() { printf '%s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
fail() {
  printf '    ASSERTION FAILED: %s\n' "$*"
  exit 1
}
assert_eq() { [ "$1" = "$2" ] || fail "$3: expected '$1', got '$2'"; }
assert_ne() { [ "$1" != "$2" ] || fail "$3: expected anything but '$1'"; }
assert_file() { [ -s "$1" ] || fail "expected non-empty file $1"; }
assert_contains() { grep -F -q -- "$2" "$1" || fail "${3:-$1}: expected to contain '$2'"; }
assert_not_contains() { ! grep -F -q -- "$2" "$1" || fail "${3:-$1}: must not contain '$2'"; }

# "<udid>\t<state>\t<name>" for the default device set, or for set $1.
devices_tsv() {
  local json
  if [ $# -gt 0 ]; then
    json=$(xcrun simctl --set "$1" list devices -j)
  else
    json=$(xcrun simctl list devices -j)
  fi
  printf '%s' "$json" | "$PY" -I -c '
import json, sys
for devices in json.load(sys.stdin).get("devices", {}).values():
    for d in devices:
        print("%s\t%s\t%s" % (d.get("udid", ""), d.get("state", ""), d.get("name", "")))
'
}
# Names in the default set that start with mc-T-0012- (sorted).
t0012_sim_names() { devices_tsv | awk -F '\t' 'index($3, "mc-T-0012-") == 1 { print $3 }' | sort; }
sim_exists() { devices_tsv | awk -F '\t' -v n="$1" '$3 == n { f = 1 } END { exit !f }'; }
out_value() { grep "^$2=" "$1" | head -n 1 | cut -d= -f2-; }
png_height() { sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight:/ { print $2 }'; }
summary_row() { grep -F "| \`$2\` |" "$1" | head -n 1; }

run_e2e() {
  local out=$1
  shift
  "$BASH_BIN" "$E2E" "$@" >"$out" 2>&1
}

# start_e2e_bg <out> args...: sets BG_PID.
start_e2e_bg() {
  local out=$1
  shift
  "$BASH_BIN" "$E2E" "$@" >"$out" 2>&1 &
  BG_PID=$!
  echo "$BG_PID" >>"$BG_PIDS_FILE"
}

# wait_pid <pid> <timeout-s>: returns the process' exit code, 124 on timeout.
wait_pid() {
  local pid=$1 limit=$2 waited=0 rc=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      note "pid $pid still running after ${limit} s; sending SIGTERM"
      kill -TERM "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" || rc=$?
  return "$rc"
}

# wait_for_line <file> <fixed-string> <timeout-s>
wait_for_line() {
  local waited=0
  until grep -F -q -- "$2" "$1" 2>/dev/null; do
    [ "$waited" -lt "$3" ] || return 1
    sleep 1
    waited=$((waited + 1))
  done
}

# make_png <width> <height> <path>: deterministic grayscale PNG.
make_png() {
  "$PY" -I -c '
import struct, sys, zlib
w, h, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
def chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
raw = b"".join(b"\x00" + bytes((x + y) % 256 for x in range(w)) for y in range(h))
with open(path, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
' "$1" "$2" "$3"
}

# --------------------------------------------------------------- fixtures ---
write_fixture_sources() {
  local dir=$1
  mkdir -p "$dir/lib" "$dir/integration_test" "$dir/test_driver"
  cat >"$dir/lib/main.dart" <<'DART'
import 'package:flutter/material.dart';

void main() {
  runApp(const FixtureApp());
}

class FixtureApp extends StatelessWidget {
  const FixtureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const ItemListScreen(),
    );
  }
}

class ItemListScreen extends StatelessWidget {
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fixture')),
      body: ListView.builder(
        key: const Key('item_list'),
        itemCount: 20,
        itemBuilder: (context, index) {
          final title = 'Item $index';
          return ListTile(
            key: Key('item_$index'),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DetailScreen(title: title)),
            ),
          );
        },
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detail: $title')),
      body: Center(child: Text(title, key: const Key('detail_title'))),
    );
  }
}
DART
  cat >"$dir/integration_test/app_test.dart" <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:e2e_fixture/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0012 fixture: list, tap item 3, detail', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Fixture'), findsOneWidget);
    await binding.takeScreenshot('01_list');

    await tester.tap(find.byKey(const Key('item_3')));
    await tester.pumpAndSettle();
    expect(find.text('Detail: Item 3'), findsOneWidget);
    await binding.takeScreenshot('02_detail');
  });
}
DART
  cat >"$dir/test_driver/integration_test.dart" <<'DART'
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host-side driver: writes each in-test screenshot to $SCREENSHOT_DIR.
Future<void> main() async {
  final outDir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('$outDir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('SCREENSHOT_WRITTEN ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
DART
}

# The failing variant: same app, but the test expects a detail screen that
# never appears (after taking the first screenshot).
write_failing_test() {
  cat >"$1/integration_test/app_test.dart" <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:e2e_fixture/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0012 fixture: deliberately failing journey', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01_list');

    await tester.tap(find.byKey(const Key('item_3')));
    await tester.pumpAndSettle();
    expect(find.text('Detail: Item 99'), findsOneWidget, reason: 'T0012_DELIBERATE_FAILURE');
  });
}
DART
}

# Builds the fixture once per suite run, then copies it (before any build, so
# every copy has its own build/ folder; F-0004 gotcha 8).
ensure_fixture() {
  [ -f "$WORK/.fixture-ready" ] && return 0
  local log="$OUT/fixture-create.log" t0
  t0=$(date +%s)
  note "creating fixture app in $FIX_BASE"
  if ! fvm flutter create --platforms=ios --org com.example --project-name e2e_fixture "$FIX_BASE" >"$log" 2>&1; then
    tail -n 20 "$log"
    fail "fvm flutter create failed (log: $log)"
  fi
  if ! (cd "$FIX_BASE" && fvm flutter pub add 'dev:integration_test:{"sdk":"flutter"}') >>"$log" 2>&1; then
    tail -n 20 "$log"
    fail "fvm flutter pub add integration_test failed (log: $log)"
  fi
  rm -f "$FIX_BASE/test/widget_test.dart"
  write_fixture_sources "$FIX_BASE"
  cp -R "$FIX_BASE" "$FIX_PASS"
  cp -R "$FIX_BASE" "$FIX_FAIL"
  write_failing_test "$FIX_FAIL"
  cp -R "$FIX_BASE" "$FIX_PAR_E"
  cp -R "$FIX_BASE" "$FIX_PAR_V"
  touch "$WORK/.fixture-ready"
  note "fixture ready in $(($(date +%s) - t0)) s"
}

# A minimal non-Flutter project: enough for pre-flight, used with --runner-cmd.
ensure_stub_project() {
  [ -f "$STUB/pubspec.yaml" ] && return 0
  mkdir -p "$STUB/integration_test" "$STUB/test_driver"
  printf 'name: stub_project\n' >"$STUB/pubspec.yaml"
  printf '// stub target\n' >"$STUB/integration_test/stub_test.dart"
  printf '// stub driver\n' >"$STUB/test_driver/integration_test.dart"
}

# ------------------------------------------------------------------ tests ---

test_T-0012-AC1_pass_run_collects_evidence() {
  ensure_fixture
  local out="$OUT/ac1-run.out" ev="$EV/ac1" rc=0 sum shot h
  run_e2e "$out" --task "$TASK" --role engineer --project "$FIX_PASS" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" || rc=$?
  note "exit code $rc; simulator $(out_value "$out" SIMULATOR_NAME)"
  assert_eq 0 "$rc" "exit code of a passing run"

  sum="$ev/e2e-summary.md"
  assert_file "$sum"
  assert_contains "$sum" "| Result | **PASS** |"
  summary_row "$sum" integration_test/app_test.dart | grep -F -q "| PASS |" ||
    fail "summary row for integration_test/app_test.dart does not show PASS"
  assert_file "$ev/e2e-app_test.log"
  assert_contains "$ev/e2e-app_test.log" "All tests passed"

  for shot in 01_list.png 02_detail.png; do
    assert_file "$ev/$shot"
    h=$(png_height "$ev/$shot")
    [ -n "$h" ] && [ "$h" -gt 0 ] && [ "$h" -le 1200 ] || fail "$shot is ${h:-?} px tall, must be 1..1200"
    assert_contains "$sum" "[$shot]($shot)"
    # Simulator screenshots are 2622 px tall, so the downscale path must have run.
    grep -F "[$shot]($shot)" "$sum" | grep -F -q "downscaled from" ||
      fail "summary does not record that $shot was downscaled"
    note "$shot: $h px tall"
  done
}

test_T-0012-AC2_failing_target_reports_fail() {
  ensure_fixture
  local out="$OUT/ac2-run.out" ev="$EV/ac2" rc=0 sum
  run_e2e "$out" --task "$TASK" --role engineer --project "$FIX_FAIL" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" || rc=$?
  note "exit code $rc; simulator $(out_value "$out" SIMULATOR_NAME)"
  assert_ne 0 "$rc" "exit code of a failing run"
  assert_eq 1 "$rc" "exit code of a failing run (documented: 1 = a target failed)"

  sum="$ev/e2e-summary.md"
  assert_file "$sum"
  assert_contains "$sum" "| Result | **FAIL** |"
  summary_row "$sum" integration_test/app_test.dart | grep -F -q "| FAIL |" ||
    fail "summary row for integration_test/app_test.dart does not show FAIL"
  assert_file "$ev/e2e-app_test.log"
  assert_contains "$ev/e2e-app_test.log" "T0012_DELIBERATE_FAILURE" "failure log"
  assert_not_contains "$ev/e2e-app_test.log" "All tests passed" "failure log"
}

test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint() {
  ensure_fixture
  local before after rc name udid out leftovers
  before=$(t0012_sim_names)

  # 1) passing run
  out="$OUT/ac3-pass.out"
  rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$FIX_PASS" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/ac3-pass" || rc=$?
  name=$(out_value "$out" SIMULATOR_NAME)
  note "pass run: exit $rc, simulator $name"
  assert_eq 0 "$rc" "pass run exit code"
  [ -n "$name" ] || fail "pass run did not report a simulator name"
  ! sim_exists "$name" || fail "simulator $name still exists after the passing run"

  # 2) failing run
  out="$OUT/ac3-fail.out"
  rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$FIX_FAIL" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/ac3-fail" || rc=$?
  name=$(out_value "$out" SIMULATOR_NAME)
  note "fail run: exit $rc, simulator $name"
  assert_ne 0 "$rc" "fail run exit code"
  [ -n "$name" ] || fail "fail run did not report a simulator name"
  ! sim_exists "$name" || fail "simulator $name still exists after the failing run"

  # 3) SIGINT while the runner (flutter drive) is executing. Job control (-m)
  # is needed: without it, bash starts background jobs with SIGINT ignored and
  # the script could never trap it (F-0005).
  out="$OUT/ac3-sigint.out"
  set -m
  start_e2e_bg "$out" --task "$TASK" --role verifier --project "$FIX_PASS" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/ac3-sigint"
  set +m
  wait_for_line "$out" "Running target 1/" 180 || fail "run never reached the runner (see $out)"
  name=$(out_value "$out" SIMULATOR_NAME)
  udid=$(out_value "$out" SIMULATOR_UDID)
  sim_exists "$name" || fail "simulator $name should exist while the run is in progress"
  sleep 3
  pgrep -f -- "-d $udid" >/dev/null || fail "runner for $udid is not running at the time of SIGINT"
  note "sending SIGINT to pid $BG_PID while flutter drive runs on $name"
  kill -INT "$BG_PID"
  rc=0
  wait_pid "$BG_PID" 90 || rc=$?
  note "interrupted run: exit $rc"
  assert_eq 130 "$rc" "exit code after SIGINT"
  # The trap's messages must reach the script's own stdout/stderr, not the
  # target log (regression: a redirect on the waiting function captured them).
  assert_contains "$out" "received SIGINT"
  assert_contains "$out" "Deleted simulator $name"
  assert_not_contains "$EV/ac3-sigint/e2e-app_test.log" "Deleted simulator" "target log"
  ! sim_exists "$name" || fail "simulator $name still exists after SIGINT"
  assert_contains "$EV/ac3-sigint/e2e-summary.md" "INTERRUPTED"
  # Review nit 10: the interrupted target's row links its log.
  summary_row "$EV/ac3-sigint/e2e-summary.md" integration_test/app_test.dart |
    grep -F -q "| INTERRUPTED |" || fail "interrupted target row does not say INTERRUPTED"
  summary_row "$EV/ac3-sigint/e2e-summary.md" integration_test/app_test.dart |
    grep -F -q "[e2e-app_test.log](e2e-app_test.log)" || fail "interrupted target row does not link its log"
  sleep 2
  if pgrep -f -- "-d $udid" >/dev/null; then
    pgrep -fl -- "-d $udid" | sed 's/^/      /'
    fail "runner processes for $udid survived the SIGINT"
  fi

  after=$(t0012_sim_names)
  leftovers=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d')
  [ -z "$leftovers" ] || fail "new mc-T-0012-* simulators left behind: $leftovers"
  [ -z "$after" ] || note "note: pre-existing mc-T-0012-* simulators (not ours): $after"
}

test_T-0012-AC4_parallel_runs_isolated() {
  ensure_fixture
  local out_e="$OUT/ac4-engineer.out" out_v="$OUT/ac4-verifier.out" pid_e pid_v rc_e=0 rc_v=0
  local name_e name_v udid_e udid_v start_e start_v end_e end_v
  start_e2e_bg "$out_e" --task "$TASK" --role engineer --project "$FIX_PAR_E" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/ac4-engineer"
  pid_e=$BG_PID
  start_e2e_bg "$out_v" --task "$TASK" --role verifier --project "$FIX_PAR_V" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/ac4-verifier"
  pid_v=$BG_PID
  wait_pid "$pid_e" 900 || rc_e=$?
  wait_pid "$pid_v" 900 || rc_v=$?
  name_e=$(out_value "$out_e" SIMULATOR_NAME)
  name_v=$(out_value "$out_v" SIMULATOR_NAME)
  udid_e=$(out_value "$out_e" SIMULATOR_UDID)
  udid_v=$(out_value "$out_v" SIMULATOR_UDID)
  note "engineer: exit $rc_e, $name_e ($udid_e)"
  note "verifier: exit $rc_v, $name_v ($udid_v)"
  assert_eq 0 "$rc_e" "engineer run exit code"
  assert_eq 0 "$rc_v" "verifier run exit code"

  case $name_e in mc-T-0012-engineer-*) ;; *) fail "engineer simulator name '$name_e'" ;; esac
  case $name_v in mc-T-0012-verifier-*) ;; *) fail "verifier simulator name '$name_v'" ;; esac
  assert_ne "$name_e" "$name_v" "simulator names"
  [ -n "$udid_e" ] && [ -n "$udid_v" ] || fail "missing simulator UDID"
  assert_ne "$udid_e" "$udid_v" "simulator UDIDs"

  # The two simulators really existed at the same time.
  start_e=$(out_value "$out_e" SIMULATOR_CREATED_AT)
  start_v=$(out_value "$out_v" SIMULATOR_CREATED_AT)
  end_e=$(out_value "$out_e" SIMULATOR_DELETED_AT)
  end_v=$(out_value "$out_v" SIMULATOR_DELETED_AT)
  [ -n "$start_e" ] && [ -n "$start_v" ] && [ -n "$end_e" ] && [ -n "$end_v" ] || fail "missing lifecycle timestamps"
  local latest_start=$start_e earliest_end=$end_e
  [ "$start_v" -gt "$latest_start" ] && latest_start=$start_v
  [ "$end_v" -lt "$earliest_end" ] && earliest_end=$end_v
  [ "$latest_start" -lt "$earliest_end" ] || fail "the two simulators' lifetimes did not overlap"
  note "simulators overlapped for $((earliest_end - latest_start)) s"

  local role
  for role in engineer verifier; do
    assert_contains "$EV/ac4-$role/e2e-summary.md" "| Result | **PASS** |"
    assert_file "$EV/ac4-$role/01_list.png"
    assert_file "$EV/ac4-$role/02_detail.png"
  done
  ! sim_exists "$name_e" || fail "$name_e still exists"
  ! sim_exists "$name_v" || fail "$name_v still exists"
}

test_T-0012-AC5_bad_runtime_or_device_fails_fast() {
  ensure_stub_project
  local before after case_name flag value out t0 elapsed rc
  before=$(t0012_sim_names)
  for case_name in runtime device; do
    if [ "$case_name" = runtime ]; then
      flag=--runtime
      value=com.apple.CoreSimulator.SimRuntime.iOS-99-9
    else
      flag=--device
      value="iPhone 99 Ultra"
    fi
    out="$OUT/ac5-$case_name.out"
    t0=$(date +%s)
    rc=0
    if [ "$case_name" = runtime ]; then
      run_e2e "$out" --task "$TASK" --role engineer --project "$STUB" \
        --device "$DEVICE" --runtime "$value" --evidence-dir "$EV/ac5" || rc=$?
    else
      run_e2e "$out" --task "$TASK" --role engineer --project "$STUB" \
        --device "$value" --runtime "$RUNTIME" --evidence-dir "$EV/ac5" || rc=$?
    fi
    elapsed=$(($(date +%s) - t0))
    note "bad $flag '$value': exit $rc in ${elapsed} s: $(grep 'error:' "$out" | head -n 1)"
    assert_ne 0 "$rc" "exit code for bad $flag"
    assert_eq 2 "$rc" "exit code for bad $flag (documented: 2 = pre-flight failure)"
    [ "$elapsed" -lt 10 ] || fail "bad $flag took ${elapsed} s, must be < 10 s"
    assert_contains "$out" "'$value'" "error output for bad $flag"
    assert_not_contains "$out" "SIMULATOR_NAME=" "output for bad $flag"
  done
  after=$(t0012_sim_names)
  assert_eq "$before" "$after" "mc-T-0012-* simulators before vs after"
  [ ! -e "$EV/ac5/e2e-summary.md" ] || fail "a failed pre-flight must not write a summary"
}

test_T-0012-AC6_cleanup_only_mc_simulators() {
  # Uses a private simctl device set: running the real cleanup on the default
  # set would also delete other crew members' live mc- simulators.
  local ds="$WORK/device-set-ac6" a b c ua ub uc out rc listed
  mkdir -p "$ds"
  echo "$ds" >>"$DEVSETS_FILE"
  a="mc-T-0012-orphan-a-$SUITE_PID"
  b="mc-T-0012-orphan-b-$SUITE_PID"
  c="zz-T-0012-control-$SUITE_PID"
  ua=$(xcrun simctl --set "$ds" create "$a" "$DEVICE" "$RUNTIME")
  ub=$(xcrun simctl --set "$ds" create "$b" "$DEVICE" "$RUNTIME")
  uc=$(xcrun simctl --set "$ds" create "$c" "$DEVICE" "$RUNTIME")
  # A run killed with SIGKILL leaves its simulator booted: simulate that.
  xcrun simctl --set "$ds" boot "$ua"
  xcrun simctl --set "$ds" bootstatus "$ua" -b >/dev/null
  note "private set: $a (Booted), $b (Shutdown), control $c"

  # --dry-run deletes nothing.
  out="$OUT/ac6-dry-run.out"
  rc=0
  "$BASH_BIN" "$CLEANUP" --device-set "$ds" --dry-run >"$out" 2>&1 || rc=$?
  assert_eq 0 "$rc" "dry-run exit code"
  assert_contains "$out" "would delete: $a ($ua)"
  assert_contains "$out" "would delete: $b ($ub)"
  assert_not_contains "$out" "$c"
  devices_tsv "$ds" >"$OUT/ac6-after-dry-run.tsv"
  assert_contains "$OUT/ac6-after-dry-run.tsv" "$ua${TAB}Booted${TAB}$a"
  assert_contains "$OUT/ac6-after-dry-run.tsv" "$ub${TAB}Shutdown${TAB}$b"
  assert_contains "$OUT/ac6-after-dry-run.tsv" "$uc${TAB}Shutdown${TAB}$c"

  # Real run: every mc- simulator goes, the control one is untouched.
  out="$OUT/ac6-cleanup.out"
  rc=0
  "$BASH_BIN" "$CLEANUP" --device-set "$ds" >"$out" 2>&1 || rc=$?
  assert_eq 0 "$rc" "cleanup exit code"
  assert_contains "$out" "deleted: $a ($ua)"
  assert_contains "$out" "deleted: $b ($ub)"
  devices_tsv "$ds" >"$OUT/ac6-after-cleanup.tsv"
  assert_not_contains "$OUT/ac6-after-cleanup.tsv" "$ua"
  assert_not_contains "$OUT/ac6-after-cleanup.tsv" "$ub"
  assert_contains "$OUT/ac6-after-cleanup.tsv" "$uc${TAB}Shutdown${TAB}$c"
  [ "$(awk -F '\t' 'index($3, "mc-") == 1' "$OUT/ac6-after-cleanup.tsv")" = "" ] ||
    fail "mc- simulators remain in the private set"

  # Second run is a no-op.
  rc=0
  "$BASH_BIN" "$CLEANUP" --device-set "$ds" >"$OUT/ac6-cleanup-again.out" 2>&1 || rc=$?
  assert_eq 0 "$rc" "second cleanup exit code"
  assert_contains "$OUT/ac6-cleanup-again.out" "No simulators named mc-*"

  # --dry-run on the real default set: lists only mc- names, deletes nothing.
  local non_mc_before non_mc_after
  non_mc_before=$(devices_tsv | awk -F '\t' 'index($3, "mc-") != 1 { print $1 }' | sort)
  rc=0
  "$BASH_BIN" "$CLEANUP" --dry-run >"$OUT/ac6-default-dry-run.out" 2>&1 || rc=$?
  assert_eq 0 "$rc" "default-set dry-run exit code"
  listed=$(grep '^would delete: ' "$OUT/ac6-default-dry-run.out" | grep -v '^would delete: mc-' || true)
  [ -z "$listed" ] || fail "dry-run listed non-mc simulators: $listed"
  non_mc_after=$(devices_tsv | awk -F '\t' 'index($3, "mc-") != 1 { print $1 }' | sort)
  assert_eq "$non_mc_before" "$non_mc_after" "non-mc simulators in the default set"
  note "default set: $(printf '%s\n' "$non_mc_after" | sed '/^$/d' | wc -l | tr -d ' ') non-mc simulators untouched"

  # Delete our control simulator ourselves.
  xcrun simctl --set "$ds" delete "$uc"
  devices_tsv "$ds" >"$OUT/ac6-final.tsv"
  assert_not_contains "$OUT/ac6-final.tsv" "$uc"
}

test_T-0012-AC7_small_screenshot_not_upscaled() {
  ensure_stub_project
  local d="$WORK/ac7" rc note h
  mkdir -p "$d/out"
  make_png 300 600 "$d/small_600.png"
  make_png 600 1200 "$d/edge_1200.png"
  make_png 600 1800 "$d/tall_1800.png"

  # Unit level: the script's own downscale function (sourced, not executed).
  run_downscale() { "$BASH_BIN" -c 'source "$1"; downscale_if_tall "$2" "$3"' _ "$E2E" "$1" "$2"; }
  note=$(run_downscale "$d/small_600.png" "$d/out/small_600.png")
  note "600 px: $note"
  cmp -s "$d/small_600.png" "$d/out/small_600.png" || fail "600 px image was modified"
  assert_eq 600 "$(png_height "$d/out/small_600.png")" "height of 600 px image"
  assert_eq "unchanged 300x600" "$note" "note for 600 px image"

  note=$(run_downscale "$d/edge_1200.png" "$d/out/edge_1200.png")
  note "1200 px: $note"
  cmp -s "$d/edge_1200.png" "$d/out/edge_1200.png" || fail "1200 px image was modified"
  assert_eq "unchanged 600x1200" "$note" "note for 1200 px image"

  # Control: the same function does shrink a tall image, so "unchanged" above
  # is not just a function that never resizes.
  note=$(run_downscale "$d/tall_1800.png" "$d/out/tall_1800.png")
  note "1800 px: $note"
  assert_eq 1200 "$(png_height "$d/out/tall_1800.png")" "height of 1800 px image after downscale"

  # End to end: a runner that "takes" the small screenshot, through the real
  # script with a real simulator (also exercises --runner-cmd placeholders).
  local out="$OUT/ac7-run.out" ev="$EV/ac7" udid
  rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --runner-cmd "echo runner-udid={udid} runner-target={target} && cp '$d/small_600.png' \"\$SCREENSHOT_DIR/small_600.png\"" || rc=$?
  udid=$(out_value "$out" SIMULATOR_UDID)
  note "stub run: exit $rc on $(out_value "$out" SIMULATOR_NAME)"
  assert_eq 0 "$rc" "stub run exit code"
  assert_contains "$ev/e2e-stub_test.log" "runner-udid=$udid runner-target=integration_test/stub_test.dart"
  cmp -s "$d/small_600.png" "$ev/small_600.png" || fail "evidence copy of the 600 px screenshot differs from the original"
  assert_eq 600 "$(png_height "$ev/small_600.png")" "evidence height"
  grep -F "[small_600.png]" "$ev/e2e-summary.md" | grep -F -q "unchanged 300x600" ||
    fail "summary does not record small_600.png as unchanged"
}

# ------------------------------------------------ T-0055: build failures ---

# Helpers (defined once, t55_ prefix). A "scenario" is one line "<rc>|<text>":
# the fake runner prints <text> (printf escapes allowed) and exits <rc>. Target
# N of a run plays scenario N.

# t55_scan <log>: build_failure_marker of the script under test, sourced.
t55_scan() { "$BASH_BIN" -c 'source "$1"; build_failure_marker "$2"' _ "$E2E" "$1"; }

# t55_write_log <file> <body line>: a log shaped like the script's own, with
# the sentinel line between the header and the runner output.
t55_write_log() {
  printf '# h1\n$ cmd\n\n# note\n# --- runner output ---\n%s\nexit\n' "$2" >"$1"
}

# t55_markers: one marker per line.
t55_markers() { "$BASH_BIN" -c 'source "$1"; printf "%s\n" "${E2E_BUILD_FAIL_MARKERS[@]}"' _ "$E2E"; }

# t55_fake_run <name> <project> <scenario-file> [extra e2e args...]
# Runs the real script on a real simulator with the fake runner and one target
# per scenario. Sets T55_RC, T55_OUT, T55_SUM.
t55_fake_run() {
  local name=$1 project=$2 scen=$3 d="$WORK/t55-$1" n=0 total targs=()
  shift 3
  mkdir -p "$d"
  cp "$scen" "$d/scen"
  printf '#!/bin/bash\nn=$(cat "$1" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$1"\nIFS="|" read -r rc text < <(sed -n "${n}p" "$2")\nprintf "$text\\n"\nexit "$rc"\n' >"$d/fake_runner.sh"
  chmod +x "$d/fake_runner.sh"
  echo 0 >"$d/cnt"
  total=$(wc -l <"$d/scen" | tr -d ' ')
  while [ "$n" -lt "$total" ]; do
    targs+=(--target integration_test/stub_test.dart)
    n=$((n + 1))
  done
  T55_OUT="$OUT/t55-$name-run.out"
  T55_SUM="$EV/t55-$name/e2e-summary.md"
  T55_RC=0
  run_e2e "$T55_OUT" --task "$TASK" --role engineer --project "$project" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/t55-$name" \
    "${targs[@]}" "$@" --runner-cmd "'$d/fake_runner.sh' '$d/cnt' '$d/scen'" || T55_RC=$?
  note "$name: exit $T55_RC on $(out_value "$T55_OUT" SIMULATOR_NAME)"
}

# t55_row <n>: the n-th target row of the last run's summary.
t55_row() { grep '^| `integration_test' "$T55_SUM" | sed -n "${1}p"; }

# T-0055-AC1 (b, c, d) through the real script with a fake runner standing in
# for flutter drive: a good target is PASS, a runtime failure is FAIL (plain),
# a compile error that exits 0 is FAIL "build failed", and a compile error as
# the only target is FAIL.
test_T-0055-AC1_good_pass_runtime_fail_build_fail() {
  ensure_stub_project
  local scen="$WORK/t55-ac1.scen"
  printf '%s\n' \
    '0|flutter: 00:01 +1: All tests passed!' \
    "0|Failed to build iOS app\\n    ** BUILD FAILED **\\nApplication failed to start on attempt: 1\\nflutter: 00:01 +1: All tests passed!" \
    '1|flutter: 00:01 +0 -1: Some tests failed.' \
    '0|flutter: 00:01 +1: All tests passed!' >"$scen"
  t55_fake_run ac1-mixed "$STUB" "$scen"
  assert_eq 1 "$T55_RC" "exit code with failing targets"
  t55_row 1 | grep -q '| PASS |' || fail "T-0055-AC1d: good target is not PASS: $(t55_row 1)"
  t55_row 2 | grep -q '| FAIL (build failed: ' || fail "T-0055-AC1a: build failure after a pass is not FAIL (build failed): $(t55_row 2)"
  t55_row 3 | grep -q '| FAIL |' || fail "T-0055-AC1c: runtime failure is not a plain FAIL: $(t55_row 3)"
  t55_row 4 | grep -q '| PASS |' || fail "T-0055-AC1d: good target after failures is not PASS: $(t55_row 4)"
  printf '%s\n' "0|    integration_test/x_test.dart:8:19: Error: A value of type 'String' can't be assigned" >"$scen"
  t55_fake_run ac1-alone "$STUB" "$scen"
  assert_eq 1 "$T55_RC" "T-0055-AC1b exit code of a broken target alone"
  t55_row 1 | grep -q '| FAIL (build failed: Dart compile error)' || fail "T-0055-AC1b: $(t55_row 1)"
}

# T-0055-AC2, unit level: every marker in E2E_BUILD_FAIL_MARKERS, and a Dart
# compile error line, makes build_failure_marker report a failure when it
# appears after the sentinel of a log; a clean log, a bare "Error:", and a
# marker only before the sentinel (the command echoed in the header) do not.
test_T-0055-AC2_every_marker_is_found_in_a_log() {
  local d="$WORK/t55ac2u" markers m n=0
  mkdir -p "$d"
  markers=$(t55_markers)
  [ -n "$markers" ] || fail "no markers listed in E2E_BUILD_FAIL_MARKERS"
  while IFS= read -r m; do
    n=$((n + 1))
    t55_write_log "$d/marker-$n.log" "some prefix $m some suffix"
    t55_scan "$d/marker-$n.log" >/dev/null || fail "marker '$m' was not found in a log"
    note "found: $m"
  done <<EOF
$markers
EOF
  [ "$n" -ge 5 ] || fail "expected at least the 5 markers named in T-0055, got $n"
  t55_write_log "$d/dart.log" "    integration_test/x_test.dart:8:19: Error: A value of type 'String' can't be assigned"
  t55_scan "$d/dart.log" >/dev/null || fail "a Dart compile error line was not found"
  note "found: Dart compile error line"
  # Controls: these must NOT be reported.
  t55_write_log "$d/clean.log" "flutter: 00:00 +1: All tests passed!"
  t55_scan "$d/clean.log" >/dev/null && fail "a clean log was reported as a build failure"
  t55_write_log "$d/error-word.log" "Error: something at runtime, not a compile error in a .dart file"
  t55_scan "$d/error-word.log" >/dev/null && fail "'Error:' without a file:line:col was reported"
  t55_write_log "$d/retry.log" "Application failed to start on attempt: 1"
  t55_scan "$d/retry.log" >/dev/null && fail "a launch retry alone was reported as a build failure"
  printf '# h1\n$ echo BUILD FAILED\n\n# note\n# --- runner output ---\nok\n' >"$d/header.log"
  t55_scan "$d/header.log" >/dev/null && fail "a marker before the sentinel was reported"
  note "controls: clean log, bare 'Error:', a launch retry and a marker in the header are not reported"
}

# T-0055-AC2, through the real script (a real simulator, a fake runner): a
# runner that prints a marker and exits 0 is FAIL with "build failed" in the
# summary, for every marker and a Dart error line; a launch retry that
# recovered (attempt-1 line, no build error, exit 0) is PASS; the same retry
# line next to "Could not build the application" is FAIL.
test_T-0055-AC2_fake_runner_printing_a_marker_with_exit_0_is_fail() {
  ensure_stub_project
  local scen="$WORK/t55-ac2.scen" m n=0 total
  : >"$scen"
  while IFS= read -r m; do
    printf '0|%s\n' "$m" >>"$scen"
  done <<EOF
$(t55_markers)
EOF
  printf '%s\n' \
    "0|integration_test/x_test.dart:8:19: Error: bad type" \
    "0|Application failed to start on attempt: 1\\nflutter: 00:01 +1: All tests passed!" \
    "0|Application failed to start on attempt: 1\\nCould not build the application for the simulator." \
    "0|All tests passed!" >>"$scen"
  total=$(wc -l <"$scen" | tr -d ' ')
  t55_fake_run ac2-markers "$STUB" "$scen"
  assert_eq 1 "$T55_RC" "exit code with failing targets"
  n=0
  while [ "$n" -lt $((total - 3)) ]; do
    n=$((n + 1))
    t55_row "$n" | grep -q '| FAIL (build failed: ' || fail "scenario $n is not FAIL (build failed): $(t55_row "$n")"
  done
  t55_row $((total - 2)) | grep -q '| PASS |' || fail "recovered launch retry is not PASS: $(t55_row $((total - 2)))"
  t55_row $((total - 1)) | grep -q '| FAIL (build failed: Could not build the application)' || fail "retry plus build error is not FAIL: $(t55_row $((total - 1)))"
  t55_row "$total" | grep -q '| PASS |' || fail "clean target is not PASS: $(t55_row "$total")"
  assert_contains "$T55_SUM" "FAIL (build failed: BUILD FAILED)"
  assert_contains "$T55_SUM" "FAIL (build failed: Dart compile error)"
  assert_contains "$T55_OUT" "RESULT: FAIL"
}

# T-0055-AC2 (header): a runner command that merely mentions BUILD FAILED.
test_T-0055-AC2_command_text_with_marker_is_not_a_failure() {
  ensure_stub_project
  local ev="$EV/t55-cmdtext" out="$OUT/t55-cmdtext-run.out" rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --runner-cmd "echo 'about BUILD FAILED' >/dev/null" || rc=$?
  note "exit $rc on $(out_value "$out" SIMULATOR_NAME)"
  assert_eq 0 "$rc" "exit code of a runner whose command text mentions BUILD FAILED"
  assert_contains "$ev/e2e-summary.md" "| PASS |"
  grep -q 'BUILD FAILED' "$ev/e2e-stub_test.log" || fail "the log header should still show the command text"
}

# T-0055 review: remove_stale_app deletes build/ios/iphonesimulator only for
# the default `flutter drive` kind of runner, never with --keep-build,
# --use-application-binary or --no-build, and the log note tells the truth
# about the uninstall. Unit level: the script is sourced, xcrun is a stub.
test_T-0055-AC1_stale_build_dir_removed_only_for_flutter_drive_runner() {
  local d="$WORK/t55keep" res log
  mkdir -p "$d"
  case_run() { # <runner-cmd> <keep-build 0|1> <xcrun-rc>: prints "kept" or "removed", note in $d/log
    rm -rf "$d/proj"
    mkdir -p "$d/proj/build/ios/iphonesimulator/Runner.app"
    : >"$d/log"
    "$BASH_BIN" -c '
      source "$1"
      xcrun() { return "$XRC"; }
      PROJECT_DIR=$2; RUNNER_CMD_TEMPLATE=$3; KEEP_BUILD=$4; SIM_UDID=U; BUNDLE_ID_RESOLVED=com.x.app
      E2E_LOG_SENTINEL="# --- runner output ---"
      XRC=$5
      remove_stale_app "$6"
    ' _ "$E2E" "$d/proj" "$1" "$2" "$3" "$d/log" 2>/dev/null
    if [ -e "$d/proj/build/ios/iphonesimulator" ]; then echo kept; else echo removed; fi
  }
  res=$(case_run 'fvm flutter drive --driver={driver} --target={target} -d {udid}' 0 0)
  assert_eq removed "$res" "default flutter drive runner"
  grep -q '^# e2e_ios.sh: uninstalled com.x.app; removed build/ios/iphonesimulator$' "$d/log" || fail "note: $(cat "$d/log")"
  res=$(case_run 'fvm flutter drive --driver={driver} --target={target} -d {udid}' 0 1)
  assert_eq removed "$res" "default runner, uninstall failing"
  grep -q 'uninstall of com.x.app failed or app not installed' "$d/log" || fail "failed uninstall must not be logged as done: $(cat "$d/log")"
  grep -q '^# e2e_ios.sh: uninstalled' "$d/log" && fail "log claims an uninstall that failed"
  res=$(case_run 'fvm flutter drive --driver={driver} --target={target} -d {udid}' 1 0)
  assert_eq kept "$res" "--keep-build"
  res=$(case_run 'fvm flutter drive --no-build --driver={driver} --target={target} -d {udid}' 0 0)
  assert_eq kept "$res" "--no-build runner"
  res=$(case_run 'flutter drive --use-application-binary=/x/Runner.app --target={target}' 0 0)
  assert_eq kept "$res" "--use-application-binary runner"
  res=$(case_run 'bash ./my_runner.sh {target}' 0 0)
  assert_eq kept "$res" "custom (non flutter drive) runner"
  grep -q 'kept build/ios/iphonesimulator' "$d/log" || fail "note should say the build dir was kept: $(cat "$d/log")"
  grep -q '^# --- runner output ---$' "$d/log" || fail "sentinel line missing from the log"
  note "default: removed; --keep-build, --no-build, --use-application-binary, custom runner: kept"
  unset -f case_run
}

# T-0055 review, through the real script: --keep-build is accepted and keeps
# the build dir; without it a flutter-drive-style runner finds it deleted.
test_T-0055-AC1_keep_build_flag_through_the_script() {
  ensure_stub_project
  local proj="$WORK/t55keep-e2e"
  rm -rf "$proj"
  cp -R "$STUB" "$proj"
  mkdir -p "$proj/build/ios/iphonesimulator"
  : >"$proj/build/ios/iphonesimulator/stale"
  # The "flutter drive" words only make the script treat it as that kind of runner.
  local cmd_gone="test ! -e '$proj/build/ios/iphonesimulator/stale' # flutter drive"
  local cmd_kept="test -e '$proj/build/ios/iphonesimulator/stale' # flutter drive"
  local out="$OUT/t55-keep-run.out" ev="$EV/t55-keep" rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$proj" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --keep-build --runner-cmd "$cmd_kept" || rc=$?
  note "--keep-build: exit $rc on $(out_value "$out" SIMULATOR_NAME)"
  assert_eq 0 "$rc" "runner finds the build dir with --keep-build"
  rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$proj" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --runner-cmd "$cmd_gone" || rc=$?
  note "default: exit $rc on $(out_value "$out" SIMULATOR_NAME)"
  assert_eq 0 "$rc" "runner finds the build dir deleted by default"
}

# T-0055 review: the bundle id is the Debug id; a $(VAR) value is refused; the
# pbxproj fallback skips RunnerTests; --bundle-id wins.
test_T-0055-AC1_bundle_id_resolution() {
  local d="$WORK/t55bid" res
  rm -rf "$d"
  mkdir -p "$d/ok/ios/Runner.xcodeproj" "$d/var/ios/Runner.xcodeproj" "$d/none"
  printf '\t\tPRODUCT_BUNDLE_IDENTIFIER = com.x.RunnerTests;\n\t\tPRODUCT_BUNDLE_IDENTIFIER = com.x.app;\n' >"$d/ok/ios/Runner.xcodeproj/project.pbxproj"
  printf '\t\tPRODUCT_BUNDLE_IDENTIFIER = "$(APP_ID)";\n' >"$d/var/ios/Runner.xcodeproj/project.pbxproj"
  bid() { "$BASH_BIN" -c 'source "$1"; PROJECT_DIR=$2; BUNDLE_ID=$3; project_bundle_id' _ "$E2E" "$1" "${2:-}"; }
  res=$(bid "$d/ok")
  assert_eq com.x.app "$res" "fallback parse skips RunnerTests"
  res=$(bid "$d/var")
  assert_eq "" "$res" "a \$(VAR) value is refused"
  res=$(bid "$d/none")
  assert_eq "" "$res" "no Xcode project gives nothing"
  res=$(bid "$d/ok" com.y.override)
  assert_eq com.y.override "$res" "--bundle-id wins"
  unset -f bid
}

# ------------------------------------------- code-review regression tests ---
# Each one is named after the AC whose guarantee it protects.

# Review finding 1: a screenshot that can't be written is an error (exit 4),
# never a summary entry for a file that doesn't exist.
test_T-0012-AC1_unwritable_screenshot_is_an_error_not_a_phantom() {
  ensure_stub_project
  local d="$WORK/review1" rc out ev note
  mkdir -p "$d/ro"
  make_png 300 600 "$d/small.png"
  make_png 600 1800 "$d/tall.png"
  chmod 555 "$d/ro"

  # Unit level, both branches (cp and sips) of the sourced function.
  rc=0
  "$BASH_BIN" -c 'source "$1"; downscale_if_tall "$2" "$3"' _ "$E2E" "$d/small.png" "$d/ro/small.png" \
    >"$d/note-cp.txt" 2>"$OUT/ac1-review-unit-cp.err" || rc=$?
  note=$(cat "$d/note-cp.txt")
  assert_ne 0 "$rc" "downscale_if_tall exit code when cp can't write"
  assert_eq "" "$note" "note printed for a failed copy"
  [ ! -e "$d/ro/small.png" ] || fail "a failed copy left $d/ro/small.png"
  rc=0
  "$BASH_BIN" -c 'source "$1"; downscale_if_tall "$2" "$3"' _ "$E2E" "$d/tall.png" "$d/ro/tall.png" \
    >"$d/note-sips.txt" 2>"$OUT/ac1-review-unit-sips.err" || rc=$?
  note=$(cat "$d/note-sips.txt")
  assert_ne 0 "$rc" "downscale_if_tall exit code when sips can't write"
  assert_eq "" "$note" "note printed for a failed downscale"
  [ ! -e "$d/ro/tall.png" ] || fail "a failed downscale left $d/ro/tall.png"
  chmod 755 "$d/ro"
  note "unit: cp and sips failures both return non-zero with no note"

  # End to end: the runner makes the evidence file read-only, so the copy fails.
  ev="$EV/ac1-review"
  out="$OUT/ac1-review-run.out"
  cat >"$d/runner.sh" <<'SH'
cp "$1" "$SCREENSHOT_DIR/shot.png"
: >"$2/shot.png"
chmod 444 "$2/shot.png"
SH
  rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --runner-cmd "/bin/bash '$d/runner.sh' '$d/small.png' '$ev'" || rc=$?
  note "run with an unwritable screenshot: exit $rc"
  assert_eq 4 "$rc" "exit code when a screenshot can't be written (documented: 4)"
  assert_contains "$out" "could not save screenshot"
  assert_contains "$ev/e2e-summary.md" "| Result | **ERROR (exit 4)** |"
  assert_not_contains "$ev/e2e-summary.md" "[shot.png]" "summary"
  summary_row "$ev/e2e-summary.md" integration_test/stub_test.dart | grep -F -q "| ERROR |" ||
    fail "target row does not show ERROR"
  ! sim_exists "$(out_value "$out" SIMULATOR_NAME)" || fail "simulator left after exit 4"
  chmod 644 "$ev/shot.png"
}

# Review nit 7: renamed logs and screenshots never collide.
test_T-0012-AC1_multiple_targets_get_unique_names() {
  local p="$WORK/stub_multi" d="$WORK/review7" ev="$EV/ac1-names" out="$OUT/ac1-names.out" rc f n
  mkdir -p "$p/integration_test/sub" "$d"
  printf 'name: stub_multi\n' >"$p/pubspec.yaml"
  : >"$p/integration_test/a_test.dart"
  : >"$p/integration_test/sub/a_test.dart"
  : >"$p/integration_test/a_test-2.dart"
  make_png 300 600 "$d/small.png"
  cat >"$d/runner.sh" <<'SH'
cp "$2" "$SCREENSHOT_DIR/x.png"
if [ "$1" = "integration_test/a_test.dart" ]; then cp "$2" "$SCREENSHOT_DIR/a_test-x.png"; fi
SH
  rc=0
  run_e2e "$out" --task "$TASK" --role engineer --project "$p" \
    --target integration_test/a_test.dart --target integration_test/sub/a_test.dart \
    --target integration_test/a_test-2.dart \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --runner-cmd "/bin/bash '$d/runner.sh' {target} '$d/small.png'" || rc=$?
  assert_eq 0 "$rc" "exit code"
  for f in e2e-a_test.log e2e-a_test-2.log e2e-a_test-2-2.log; do
    assert_file "$ev/$f"
    assert_contains "$ev/e2e-summary.md" "[$f]($f)"
  done
  for f in x.png a_test-x.png a_test-3-x.png a_test-2-x.png; do
    assert_file "$ev/$f"
    assert_contains "$ev/e2e-summary.md" "[$f]($f)"
  done
  n=$(grep -c '^| \[.*\.png\](' "$ev/e2e-summary.md")
  assert_eq 4 "$n" "screenshot rows in the summary"
  note "3 targets: logs e2e-a_test{,-2,-2-2}.log; screenshots x, a_test-x, a_test-3-x, a_test-2-x"
}

# Review finding 2, nits 9 and 10: a second SIGINT during teardown can't stop
# the simulator from being deleted; children that left the process tree (and
# ignore SIGTERM) are killed; the interrupted target keeps its log link and
# the screenshot it had already taken.
test_T-0012-AC3_teardown_survives_second_sigint_and_kills_orphans() {
  ensure_stub_project
  local d="$WORK/review2" ev="$EV/ac3-review" out="$OUT/ac3-review.out" token rc name
  token="T0012-orphan-$SUITE_PID"
  mkdir -p "$d"
  make_png 300 600 "$d/small.png"
  cat >"$d/runner.sh" <<'SH'
cp "$1" "$SCREENSHOT_DIR/partial.png"
# Orphan: its parent subshell exits at once, so it is re-parented to launchd
# but stays in the runner's process group. It ignores SIGTERM.
( /bin/bash -c "trap '' TERM; sleep 300; : $2" & )
# The runner itself ignores SIGTERM too, so teardown has to wait 5 s for KILL.
trap '' TERM
echo runner-started
sleep 300
SH
  set -m
  start_e2e_bg "$out" --task "$TASK" --role engineer --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$ev" \
    --runner-cmd "/bin/bash '$d/runner.sh' '$d/small.png' '$token'"
  set +m
  wait_for_line "$ev/e2e-stub_test.log" "runner-started" 120 || fail "runner never started (see $out)"
  name=$(out_value "$out" SIMULATOR_NAME)
  pgrep -f -- "$token" >/dev/null || fail "orphan process was not started"
  # Like Ctrl-C in a terminal: signal the script's whole process group (it got
  # its own via set -m), so its foreground children get SIGINT too. Signalling
  # only the pid would not reproduce the bug: bash survives a SIGINT whose
  # foreground child exits normally ("wait and cooperative exit").
  note "SIGINT to the process group, then again 1 s later during teardown ($name)"
  kill -INT -- "-$BG_PID"
  sleep 1
  kill -0 "$BG_PID" 2>/dev/null || fail "script already exited 1 s after SIGINT; teardown is not being exercised"
  kill -INT -- "-$BG_PID" 2>/dev/null || true
  rc=0
  wait_pid "$BG_PID" 60 || rc=$?
  note "exit $rc"
  assert_eq 130 "$rc" "exit code after two SIGINTs"
  assert_contains "$out" "Deleted simulator $name"
  assert_contains "$out" "SIMULATOR_DELETED_AT="
  ! sim_exists "$name" || fail "simulator $name still exists after a second SIGINT"
  sleep 1
  if pgrep -f -- "$token" >/dev/null; then
    pgrep -fl -- "$token" | sed 's/^/      /'
    pkill -KILL -f -- "$token" || true
    fail "orphaned runner child survived teardown"
  fi
  summary_row "$ev/e2e-summary.md" integration_test/stub_test.dart |
    grep -F -q "[e2e-stub_test.log](e2e-stub_test.log)" || fail "interrupted row does not link its log"
  assert_file "$ev/partial.png"
  assert_contains "$ev/e2e-summary.md" "[partial.png](partial.png)"
  assert_contains "$ev/e2e-stub_test.log" "# interrupted by SIGINT"
}

# Review finding 3: the default evidence dir is per role, and a rerun removes
# the previous run's outputs (and only those).
test_T-0012-AC4_default_evidence_dir_is_per_role_and_reset() {
  ensure_stub_project
  local repo="$WORK/fake_repo" d="$WORK/review3" e v rc_e=0 rc_v=0 pid_e pid_v rc
  mkdir -p "$repo/tool" "$d"
  cp "$E2E" "$repo/tool/e2e_ios.sh"
  e="$repo/documents/evidence/$TASK/engineer"
  v="$repo/documents/evidence/$TASK/verifier"
  mkdir -p "$e"
  printf '# E2E summary: %s (engineer)\n\nold run\n' "$TASK" >"$e/e2e-summary.md"
  make_png 10 10 "$e/stale.png"
  echo old >"$e/e2e-old.log"
  echo keep >"$e/notes.md"
  make_png 300 600 "$d/small.png"
  local runner="cp '$d/small.png' \"\$SCREENSHOT_DIR/shot.png\""

  "$BASH_BIN" "$repo/tool/e2e_ios.sh" --task "$TASK" --role engineer --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --runner-cmd "$runner" >"$OUT/ac4-review-engineer.out" 2>&1 &
  pid_e=$!
  echo "$pid_e" >>"$BG_PIDS_FILE"
  "$BASH_BIN" "$repo/tool/e2e_ios.sh" --task "$TASK" --role verifier --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --runner-cmd "$runner" >"$OUT/ac4-review-verifier.out" 2>&1 &
  pid_v=$!
  echo "$pid_v" >>"$BG_PIDS_FILE"
  wait_pid "$pid_e" 300 || rc_e=$?
  wait_pid "$pid_v" 300 || rc_v=$?
  note "engineer exit $rc_e, verifier exit $rc_v"
  assert_eq 0 "$rc_e" "engineer exit code"
  assert_eq 0 "$rc_v" "verifier exit code"
  assert_contains "$OUT/ac4-review-engineer.out" "Evidence dir: $e"
  assert_contains "$OUT/ac4-review-verifier.out" "Evidence dir: $v"
  assert_contains "$e/e2e-summary.md" "| Role | engineer |"
  assert_contains "$v/e2e-summary.md" "| Role | verifier |"
  assert_file "$e/shot.png"
  assert_file "$v/shot.png"
  [ ! -e "$e/stale.png" ] || fail "stale screenshot from the previous run is still there"
  [ ! -e "$e/e2e-old.log" ] || fail "stale log from the previous run is still there"
  assert_not_contains "$e/e2e-summary.md" "old run" "engineer summary"
  assert_file "$e/notes.md"
  note "per-role dirs written; stale.png and e2e-old.log removed; notes.md kept"

  # A dir with PNGs that this script did not write is refused before any simulator.
  mkdir -p "$d/foreign"
  make_png 10 10 "$d/foreign/someone-elses.png"
  rc=0
  run_e2e "$OUT/ac4-review-foreign.out" --task "$TASK" --role engineer --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$d/foreign" --runner-cmd true || rc=$?
  assert_eq 2 "$rc" "exit code for a foreign evidence dir"
  assert_contains "$OUT/ac4-review-foreign.out" "did not write"
  assert_not_contains "$OUT/ac4-review-foreign.out" "SIMULATOR_NAME="
  assert_file "$d/foreign/someone-elses.png"
}

# Review nit 6: fvm is required only when the runner command uses it.
test_T-0012-AC5_fvm_checked_only_when_runner_uses_it() {
  ensure_stub_project
  local nofvm="/usr/bin:/bin:/usr/sbin:/sbin" rc out
  PATH="$nofvm" command -v fvm >/dev/null 2>&1 && fail "test setup: fvm is still on $nofvm"
  out="$OUT/ac5-fvm-default.out"
  rc=0
  PATH="$nofvm" "$BASH_BIN" "$E2E" --task "$TASK" --role engineer --project "$STUB" \
    --runtime com.apple.CoreSimulator.SimRuntime.iOS-99-9 >"$out" 2>&1 || rc=$?
  assert_eq 2 "$rc" "exit code without fvm, default runner"
  assert_contains "$out" "'fvm' not found"
  out="$OUT/ac5-fvm-custom.out"
  rc=0
  PATH="$nofvm" "$BASH_BIN" "$E2E" --task "$TASK" --role engineer --project "$STUB" \
    --runtime com.apple.CoreSimulator.SimRuntime.iOS-99-9 --runner-cmd true >"$out" 2>&1 || rc=$?
  assert_eq 2 "$rc" "exit code without fvm, custom runner"
  assert_not_contains "$out" "fvm" "pre-flight output for a runner without fvm"
  assert_contains "$out" "iOS-99-9"
  note "default runner needs fvm; --runner-cmd true does not (reached the runtime check)"
}

# Review finding 4: a failing simulator listing is an error, not "nothing to do".
test_T-0012-AC6_cleanup_fails_loudly_when_listing_fails() {
  local fb="$WORK/fakebin-fail" fj="$WORK/fakebin-badjson" rc out
  mkdir -p "$fb" "$fj"
  printf '#!/bin/sh\necho "fake xcrun: simctl unavailable" >&2\nexit 1\n' >"$fb/xcrun"
  printf '#!/bin/sh\necho "this is not json"\nexit 0\n' >"$fj/xcrun"
  chmod +x "$fb/xcrun" "$fj/xcrun"
  for case_dir in "$fb" "$fj"; do
    out="$OUT/ac6-review-$(basename "$case_dir").out"
    rc=0
    PATH="$case_dir:$PATH" "$BASH_BIN" "$CLEANUP" >"$out" 2>&1 || rc=$?
    note "$(basename "$case_dir"): exit $rc"
    assert_eq 3 "$rc" "cleanup exit code when listing fails ($(basename "$case_dir"))"
    assert_contains "$out" "could not list simulators"
    assert_not_contains "$out" "No simulators named" "output ($(basename "$case_dir"))"
  done
  out="$OUT/ac6-review-missing-set.out"
  rc=0
  "$BASH_BIN" "$CLEANUP" --device-set "$WORK/no-such-device-set" >"$out" 2>&1 || rc=$?
  assert_eq 2 "$rc" "cleanup exit code for a missing --device-set"
  assert_not_contains "$out" "No simulators named" "output (missing set)"
}

# ---------------------------------------- T-0062: role names, raw trees ---

# t0062_sim_names: names in the default set that start with mc-T-0062-.
t0062_sim_names() { devices_tsv | awk -F '\t' 'index($3, "mc-T-0062-") == 1 { print $3 }' | sort; }

test_T-0062-AC3_any_role_name_is_accepted_and_its_simulator_deleted() {
  ensure_stub_project
  local out="$OUT/t0062-ac3-role.out" rc=0 name before after
  before=$(t0062_sim_names)
  run_e2e "$out" --task T-0062 --role reverify --project "$STUB" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/t0062-role" \
    --runner-cmd "echo ran" || rc=$?
  name=$(out_value "$out" SIMULATOR_NAME)
  note "role reverify: exit $rc on '$name'"
  assert_eq 0 "$rc" "exit code for --role reverify"
  [[ $name =~ ^mc-T-0062-reverify-[0-9]+$ ]] || fail "simulator name '$name' is not mc-T-0062-reverify-<pid>"
  sim_exists "$name" && fail "simulator $name was not deleted"
  after=$(t0062_sim_names)
  assert_eq "$before" "$after" "mc-T-0062-* simulators before vs after"
  assert_contains "$EV/t0062-role/e2e-summary.md" "| Role | reverify |"
}

test_T-0062-AC3_a_role_outside_a_z_0_9_dash_is_refused_before_any_simulator() {
  ensure_stub_project
  local role out rc before after
  before=$(t0062_sim_names)
  for role in Re_Verify "re verify" "../x" ""; do
    out="$OUT/t0062-ac3-badrole.out"
    rc=0
    run_e2e "$out" --task T-0062 --role "$role" --project "$STUB" --runner-cmd true || rc=$?
    note "role '$role': exit $rc"
    assert_eq 2 "$rc" "exit code for --role '$role'"
    assert_contains "$out" "--role"
    assert_not_contains "$out" "SIMULATOR_NAME=" "output for --role '$role'"
  done
  after=$(t0062_sim_names)
  assert_eq "$before" "$after" "mc-T-0062-* simulators before vs after"
}

# A raw tree (no ios/Runner.xcodeproj) with the default `flutter drive` runner
# fails once, early, naming the command to run. A prepared tree gets past the
# check (a fake fvm stands in for flutter, so no build happens). A custom
# runner is not asked for an Xcode project.
test_T-0062-AC3_raw_tree_fails_with_the_prepare_command_and_a_prepared_tree_runs() {
  local d="$WORK/t0062-raw" fb="$WORK/t0062-fakebin" out rc=0 name before after
  mkdir -p "$d/raw/integration_test" "$d/raw/test_driver" "$fb"
  printf 'name: raw_project\n' >"$d/raw/pubspec.yaml"
  printf '// stub target\n' >"$d/raw/integration_test/stub_test.dart"
  printf '// stub driver\n' >"$d/raw/test_driver/integration_test.dart"
  printf '#!/bin/sh\necho "fake fvm $*"\nexit 0\n' >"$fb/fvm"
  chmod +x "$fb/fvm"
  before=$(t0062_sim_names)

  out="$OUT/t0062-ac3-raw.out"
  PATH="$fb:$PATH" "$BASH_BIN" "$E2E" --task T-0062 --role reverify --project "$d/raw" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/t0062-raw" >"$out" 2>&1 || rc=$?
  note "raw tree: exit $rc: $(grep 'error:' "$out" | head -n 1 | cut -c1-160)"
  assert_eq 2 "$rc" "exit code for a raw tree"
  assert_contains "$out" "has no ios/Runner.xcodeproj"
  assert_contains "$out" "tool/e2e/prepare_pub_project.sh --app"
  assert_not_contains "$out" "SIMULATOR_NAME=" "output for a raw tree"
  [ ! -e "$EV/t0062-raw/e2e-summary.md" ] || fail "a failed pre-flight must not write a summary"

  # A custom runner needs no Xcode project, so the raw tree is fine for it.
  out="$OUT/t0062-ac3-raw-custom.out"
  rc=0
  run_e2e "$out" --task T-0062 --role reverify --project "$d/raw" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/t0062-raw-custom" --runner-cmd "echo ran" || rc=$?
  assert_eq 0 "$rc" "exit code for a custom runner on a raw tree"

  # The prepared tree: the check passes and a simulator is created and deleted.
  mkdir -p "$d/raw/ios/Runner.xcodeproj"
  out="$OUT/t0062-ac3-prepared.out"
  rc=0
  PATH="$fb:$PATH" "$BASH_BIN" "$E2E" --task T-0062 --role reverify --project "$d/raw" \
    --device "$DEVICE" --runtime "$RUNTIME" --evidence-dir "$EV/t0062-prepared" >"$out" 2>&1 || rc=$?
  name=$(out_value "$out" SIMULATOR_NAME)
  note "prepared tree: exit $rc on '$name'"
  assert_not_contains "$out" "has no ios/Runner.xcodeproj" "output for a prepared tree"
  [[ $name =~ ^mc-T-0062-reverify-[0-9]+$ ]] || fail "no simulator was created for the prepared tree ('$name')"
  sim_exists "$name" && fail "simulator $name was not deleted"
  after=$(t0062_sim_names)
  assert_eq "$before" "$after" "mc-T-0062-* simulators before vs after"
}

ALL_TESTS="
test_T-0012-AC1_pass_run_collects_evidence
test_T-0012-AC1_unwritable_screenshot_is_an_error_not_a_phantom
test_T-0012-AC1_multiple_targets_get_unique_names
test_T-0012-AC2_failing_target_reports_fail
test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint
test_T-0012-AC3_teardown_survives_second_sigint_and_kills_orphans
test_T-0012-AC4_parallel_runs_isolated
test_T-0012-AC4_default_evidence_dir_is_per_role_and_reset
test_T-0012-AC5_bad_runtime_or_device_fails_fast
test_T-0012-AC5_fvm_checked_only_when_runner_uses_it
test_T-0012-AC6_cleanup_only_mc_simulators
test_T-0012-AC6_cleanup_fails_loudly_when_listing_fails
test_T-0012-AC7_small_screenshot_not_upscaled
test_T-0055-AC1_good_pass_runtime_fail_build_fail
test_T-0055-AC1_stale_build_dir_removed_only_for_flutter_drive_runner
test_T-0055-AC1_keep_build_flag_through_the_script
test_T-0055-AC1_bundle_id_resolution
test_T-0055-AC2_every_marker_is_found_in_a_log
test_T-0055-AC2_fake_runner_printing_a_marker_with_exit_0_is_fail
test_T-0055-AC2_command_text_with_marker_is_not_a_failure
test_T-0062-AC3_any_role_name_is_accepted_and_its_simulator_deleted
test_T-0062-AC3_a_role_outside_a_z_0_9_dash_is_refused_before_any_simulator
test_T-0062-AC3_raw_tree_fails_with_the_prepare_command_and_a_prepared_tree_runs
"

# ----------------------------------------------------------- suite runner ---
suite_cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  set +e
  local pid name u ds waited
  # 1) stop background runs; their own traps delete their simulators.
  while read -r pid; do
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null
  done <"$BG_PIDS_FILE"
  waited=0
  while read -r pid; do
    [ -n "$pid" ] || continue
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 60 ]; do
      sleep 1
      waited=$((waited + 1))
    done
  done <"$BG_PIDS_FILE"
  # 2) sweep any simulator a run of this suite announced and that still exists.
  grep -h -E '^SIMULATOR_NAME=mc-T-00(12|62)-' "$OUT"/*.out 2>/dev/null | cut -d= -f2- | sort -u >"$WORK/announced"
  while read -r name; do
    [ -n "$name" ] || continue
    for u in $(devices_tsv | awk -F '\t' -v n="$name" '$3 == n { print $1 }'); do
      xcrun simctl shutdown "$u" >/dev/null 2>&1
      xcrun simctl delete "$u" >/dev/null 2>&1 && say "suite cleanup: deleted leftover simulator $name ($u)"
    done
  done <"$WORK/announced"
  # 3) empty the private device sets (only ones inside our temp dir).
  while read -r ds; do
    case $ds in "$WORK"/*) ;; *) continue ;; esac
    [ -d "$ds" ] || continue
    for u in $(devices_tsv "$ds" | cut -f1); do
      xcrun simctl --set "$ds" shutdown "$u" >/dev/null 2>&1
      xcrun simctl --set "$ds" delete "$u" >/dev/null 2>&1 && say "suite cleanup: deleted simulator $u from $ds"
    done
  done <"$DEVSETS_FILE"
  if [ "${E2E_TEST_KEEP:-0}" = "1" ]; then
    say "Kept temp dir: $WORK"
  else
    rm -rf "$WORK"
    # Xcode's Swift Package Manager integration leaves an empty lock file per
    # fixture build in $TMPDIR, named after the fixture path ("/" -> "_").
    rm -f "${TMPDIR:-/tmp}/$(printf '%s' "$WORK" | tr / _)"_*.lock
  fi
  exit "$rc"
}
trap suite_cleanup EXIT
trap 'say "suite interrupted"; exit 130' INT
trap 'say "suite terminated"; exit 143' TERM

run_test() {
  local t=$1 t0 rc dur id f
  say "RUN  $t"
  t0=$(date +%s)
  set +e
  (
    set -eEuo pipefail
    # stderr: with -E the trap also fires inside $(...), whose stdout is data.
    trap 'printf "    ERROR: command failed (exit %s) at line %s\n" "$?" "$LINENO" >&2' ERR
    "$t"
  )
  rc=$?
  set -e
  dur=$(($(date +%s) - t0))
  if [ "$rc" -eq 0 ]; then
    say "PASS $t (${dur} s)"
    PASSED=$((PASSED + 1))
  else
    say "FAIL $t (${dur} s)"
    FAILED=$((FAILED + 1))
    FAILED_NAMES="$FAILED_NAMES $t"
    id=$(printf '%s' "$t" | sed -E 's/.*-(AC[0-9]+)_.*/\1/' | tr 'A-Z' 'a-z')
    for f in "$OUT/$id"-*.out; do
      [ -e "$f" ] || continue
      say "    --- last lines of $(basename "$f") ---"
      tail -n 15 "$f" | sed 's/^/    | /'
    done
  fi
}

main() {
  local t sel pat match
  sel=""
  for t in $ALL_TESTS; do
    if [ $# -eq 0 ]; then
      sel="$sel $t"
      continue
    fi
    match=0
    for pat in "$@"; do
      case $t in *"$pat"*) match=1 ;; esac
    done
    [ "$match" -eq 1 ] && sel="$sel $t"
  done
  [ -n "$sel" ] || { say "no test matches: $*"; exit 2; }

  say "T-0012 e2e runner test suite"
  say "  scripts run with: $BASH_BIN ($("$BASH_BIN" -c 'echo $BASH_VERSION'))"
  say "  device: $DEVICE, runtime: $RUNTIME"
  say "  temp dir: $WORK"
  PASSED=0
  FAILED=0
  FAILED_NAMES=""
  local suite_t0
  suite_t0=$(date +%s)
  for t in $sel; do
    run_test "$t"
  done
  local total=$(($(date +%s) - suite_t0))
  say ""
  say "Summary: $PASSED passed, $FAILED failed, $((PASSED + FAILED)) total in ${total} s"
  if [ "$FAILED" -eq 0 ]; then
    say "RESULT: PASS"
    return 0
  fi
  say "Failed:$FAILED_NAMES"
  say "RESULT: FAIL"
  return 1
}

main "$@"
