#!/bin/bash
# T-0029-AC5: the R28 BDD fallback stays traceable. Stock bdd_widget_test
# 3.0.5 (build_runner, in the overlay) with `testMethodName: mcTestWidgets`
# generates spike/bdd_sample's tagged feature; each scenario's tags reach
# mcTestWidgets as `tags:` and the test names carry the AC IDs.
#
# Runs in a throwaway copy under .dart_tool/mc_overlay/ (git-ignored, outside
# //...): the stock Builder writes into its package (R10). Names come from
# `flutter test`'s JSON reporter (package:test's names, which are what the
# Bazel JUnit XML carries) and are also written as JUnit XML.
#   tool/checks/T-0029-AC5_stock_fallback.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
# The run cd's into the scratch package, so make --out absolute.
[[ -n "$OUT" && "$OUT" != /* ]] && OUT="$REPO/$OUT"
rc=0
OVERLAY="$REPO/tool/build_runner_overlay"
PKG=spike/bdd_sample
SCRATCH="$REPO/.dart_tool/mc_overlay/bdd_fallback"
report "# T-0029-AC5: stock bdd_widget_test 3.0.5 fallback keeps AC IDs in test names" ""

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/_deps" "$SCRATCH/test/feature" "$SCRATCH/assets"
cp -R "$PKG/lib" "$SCRATCH/lib"
cp "$PKG/test/feature/greeting_browse.feature" "$SCRATCH/test/feature/"
cp -R "$PKG/test/feature/step" "$PKG/test/feature/util" "$SCRATCH/test/feature/"
cp -R utility/mc_ds_theme/assets/fonts "$SCRATCH/assets/fonts"

# First-party closure: the sample's dependencies and dev_dependencies, then
# their dependencies, transitively. Prints "name<TAB>dir".
first_party=$(/usr/bin/python3 -I - "$REPO" "$PKG" <<'PY'
import os, re, sys
root, pkg = sys.argv[1], sys.argv[2]
def read(p): return open(os.path.join(root, p, "pubspec.yaml")).read()
def name(t): return re.search(r"^name:\s*(\S+)", t, re.M).group(1)
ws = re.search(r"^workspace:\n((?:\s+-\s*.+\n?)+)", read("."), re.M).group(1)
dirs = [l.split("-", 1)[1].strip() for l in ws.splitlines() if l.strip()]
by_name = {name(read(d)): d for d in dirs}
def deps(t, dev):
    out = []
    for sect in ["dependencies"] + (["dev_dependencies"] if dev else []):
        m = re.search(r"^%s:\n((?:[ \t]+.*\n?)*)" % sect, t, re.M)
        out += re.findall(r"^  ([a-z0-9_]+):", m.group(1), re.M) if m else []
    return out
seen, todo = {}, [(pkg, True)]
while todo:
    d, dev = todo.pop()
    for n in deps(read(d), dev):
        if n in by_name and n not in seen and n != "mc_analysis":
            seen[n] = by_name[n]; todo.append((by_name[n], False))
for n, d in sorted(seen.items()): print(f"{n}\t{d}")
PY
)
{
  sed -e "s/^name: .*/name: bdd_sample/" "$OVERLAY/pubspec.yaml"
  echo "dependency_overrides:"
  while IFS=$'\t' read -r dep dir; do
    mkdir -p "$SCRATCH/_deps/$dep"
    cp -R "$dir/lib" "$SCRATCH/_deps/$dep/lib"
    # The kept `flutter:` section may declare assets (mc_ds_theme's fonts).
    [[ -d "$dir/assets" ]] && cp -R "$dir/assets" "$SCRATCH/_deps/$dep/assets"
    # Drop `resolution: workspace` and the dev_dependencies block only (a
    # later top-level section such as `flutter:` stays).
    /usr/bin/python3 -I - "$dir/pubspec.yaml" > "$SCRATCH/_deps/$dep/pubspec.yaml" <<'PY'
import re, sys
out, skip = [], False
for line in open(sys.argv[1]).read().splitlines():
    if re.match(r"^\S", line):
        skip = line.startswith("dev_dependencies:")
    if not skip and not line.startswith("resolution: workspace"):
        out.append(line)
print("\n".join(out))
PY
    printf '  %s:\n    path: _deps/%s\n' "$dep" "$dep"
  done <<< "$first_party"
} > "$SCRATCH/pubspec.yaml"
# Declare the first-party packages and the hosted ones the sample imports.
/usr/bin/python3 -I - "$SCRATCH/pubspec.yaml" "$first_party" <<'PY'
import sys
p, fp = sys.argv[1], sys.argv[2]
names = [l.split("\t")[0] for l in fp.splitlines() if l.strip()]
s = open(p).read()
import re
have = set(re.findall(r"^  ([a-z0-9_]+):", s.split("\ndependencies:\n", 1)[1].split("\n\n", 1)[0], re.M))
extra = "".join(f"  {n}: any\n" for n in names + ["dio"] if n not in have)
if "flutter_test" not in have:
    extra += "  flutter_test:\n    sdk: flutter\n"
s = s.replace("\ndependencies:\n", "\ndependencies:\n" + extra, 1)
open(p, "w").write(s)
PY
cp "$OVERLAY/pubspec.lock" "$SCRATCH/pubspec.lock"

# Stock options. Shared steps can only be named by file path
# (`externalSteps` matches on the file name), so list mc_test_steps' step files
# (the same set as :step_index: lib/src/<group>/**).
{
  echo "targets:"
  echo "  \$default:"
  echo "    builders:"
  echo "      bdd_widget_test|featureBuilder:"
  echo "        options:"
  echo "          testMethodName: mcTestWidgets"
  echo "          customHeaders:"
  echo "            - \"import 'package:flutter_test/flutter_test.dart';\""
  echo "            - \"import 'package:mc_test_utils/mc_test_utils.dart';\""
  echo "          externalSteps:"
  (cd utility/mc_test_steps/lib && find src -mindepth 2 -name '*.dart' | sort) \
    | sed 's|^|            - package:mc_test_steps/|'
} > "$SCRATCH/build.yaml"
# The suite entry the fallback would also need (fixture registration once).
cat > "$SCRATCH/test/feature/fallback_all_test.dart" <<'DART'
import 'package:flutter_test/flutter_test.dart';

import 'greeting_browse_test.dart' as greeting_browse;
import 'util/greeting_env.dart' as setup;

void main() {
  setUpAll(setup.bddSetUpAll);
  group('greeting_browse', greeting_browse.main);
}
DART

cd "$SCRATCH"
log="$SCRATCH/run.log"
if ! fvm flutter pub get > "$log" 2>&1; then
  report "- FAIL: pub get" '```' "$(tail -20 "$log")" '```'; finish T-0029-AC5 1
fi
drift=$(/usr/bin/python3 -I - "$OVERLAY/pubspec.lock" "$SCRATCH/pubspec.lock" <<'PY'
import re, sys
def load(p):
    d, cur = {}, None
    for l in open(p):
        m = re.match(r"^  ([a-z0-9_]+):$", l)
        if m: cur = m.group(1)
        m = re.match(r'^    version: "(.*)"', l)
        if m and cur: d[cur] = m.group(1)
    return d
a, b = load(sys.argv[1]), load(sys.argv[2])
for k in sorted(set(a) & set(b)):
    if a[k] != b[k]: print(f"{k}: {a[k]} -> {b[k]}")
PY
)
report "- overlay resolve: bdd_widget_test $(grep -A7 '^  bdd_widget_test:' pubspec.lock | sed -n 's/.*version: "\(.*\)"/\1/p'); drift from the committed overlay lock: ${drift:-none}"
before_steps="$(ls test/feature/step | sort)"
fvm dart run build_runner build --delete-conflicting-outputs >> "$log" 2>&1 || {
  report "- FAIL: build_runner" '```' "$(tail -30 "$log")" '```'; finish T-0029-AC5 1; }
gen=test/feature/greeting_browse_test.dart
report "## Stock-generated \`$gen\`" '```dart' "$(cat "$gen")" '```'
grep -q "mcTestWidgets('''The greeting is shown'''" "$gen" || { report "- FAIL: not mcTestWidgets"; rc=1; }
grep -q "tags: \['T-0001-AC1', 'smoke'\]" "$gen" && report "- the scenario's tags reach mcTestWidgets: \`tags: ['T-0001-AC1', 'smoke']\`" \
  || { report "- FAIL: tags not passed"; rc=1; }
new_steps="$(comm -13 <(echo "$before_steps") <(ls test/feature/step | sort))"
report "- step stubs the stock Builder wrote into the package: ${new_steps:-none}"

icons="$(fvm flutter --version --machine 2>/dev/null | /usr/bin/python3 -I -c 'import json,sys; print(json.load(sys.stdin)["flutterRoot"])')/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
MC_MATERIAL_ICONS="$icons" fvm flutter test test/feature/fallback_all_test.dart \
  --file-reporter "json:$SCRATCH/results.json" >> "$log" 2>&1
code=$?
report "- \`flutter test test/feature/fallback_all_test.dart\`: exit $code"
[[ $code == 0 ]] || { report '```' "$(tail -30 "$log")" '```'; rc=1; }
junit="$SCRATCH/fallback_junit.xml"
names=$(/usr/bin/python3 -I - "$SCRATCH/results.json" "$junit" <<'PY'
import json, sys
from xml.sax.saxutils import quoteattr
tests, done = {}, {}
for line in open(sys.argv[1]):
    e = json.loads(line)
    if e.get("type") == "testStart" and not e["test"]["name"].startswith("loading "):
        tests[e["test"]["id"]] = e["test"]["name"]
    if e.get("type") == "testDone" and not e.get("hidden"):
        done[e["testID"]] = e["result"]
rows = [(tests[i], done.get(i)) for i in tests if i in done]
with open(sys.argv[2], "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<testsuites>\n')
    f.write(f'  <testsuite name="test/feature/fallback_all_test.dart" tests="{len(rows)}" failures="{sum(r != "success" for _, r in rows)}">\n')
    for n, r in rows:
        f.write(f'    <testcase name={quoteattr(n)} classname="test/feature/fallback_all_test.dart">' + ('' if r == "success" else '<failure/>') + '</testcase>\n')
    f.write('  </testsuite>\n</testsuites>\n')
for n, r in rows: print(f"{r}\t{n}")
PY
)
report "## Test names (flutter test JSON reporter; as JUnit in \`fallback_junit.xml\`)" '```' "$names" '```'
for want in '[T-0001-AC1]' '[T-0029-AC1]'; do
  grep -F "$want" <<< "$names" | grep -q '^success' && report "- a passing test name ends with $want" \
    || { report "- FAIL: no passing test named with $want"; rc=1; }
done
if [[ -n "$OUT" ]]; then
  ev="$(dirname "$OUT")"; mkdir -p "$ev"
  cp "$junit" "$ev/T-0029-AC5_fallback_junit.xml"
  cp "$gen" "$ev/T-0029-AC5_stock_greeting_browse_test.dart"
fi
finish T-0029-AC5 $rc
