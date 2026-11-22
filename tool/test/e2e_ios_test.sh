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

ALL_TESTS="
test_T-0012-AC1_pass_run_collects_evidence
test_T-0012-AC2_failing_target_reports_fail
test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint
test_T-0012-AC4_parallel_runs_isolated
test_T-0012-AC5_bad_runtime_or_device_fails_fast
test_T-0012-AC6_cleanup_only_mc_simulators
test_T-0012-AC7_small_screenshot_not_upscaled
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
  grep -h '^SIMULATOR_NAME=mc-T-0012-' "$OUT"/*.out 2>/dev/null | cut -d= -f2- | sort -u >"$WORK/announced"
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
    trap 'printf "    ERROR: command failed (exit %s) at line %s\n" "$?" "$LINENO"' ERR
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
