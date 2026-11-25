#!/bin/bash
# T-0034-AC4: retrofit paths are relative (`'v1/characters'`), because
# `apiBaseUrl` ends with `/` (mc_config normalises it). Scans every
# hand-written Dart file of the repo for an HTTP-verb annotation whose path
# starts with `/`, including annotations split over several lines, raw
# strings (`r'/x'`) and either quote style, and checks the configs'
# apiBaseUrl values end with `/`.
# FAILS on a hit, on a config without the slash, when it finds no retrofit
# annotation at all (an empty scan proves nothing), and when its negative
# controls (planted one-line, multi-line and raw samples) are not all caught.
#   tool/checks/T-0034-AC4_relative_paths.sh [--out FILE] [--role R]
# MC_T0034_ROOTS overrides the scanned roots (default: app feature spike utility).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"

# scan.py <root>...: prints "bad <file>:<line>: <annotation>" for each
# leading-slash path and "count <n>" for all verb annotations seen.
SCAN='
import os, re, sys
verb = r"@(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\(\s*(?P<raw>r?)(?P<q>[\x27\"])(?P<path>[^\x27\"]*)"
rx = re.compile(verb)
count = 0
for root in sys.argv[1:]:
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if not x.startswith("bazel-") and x != ".dart_tool"]
        for f in files:
            if not f.endswith(".dart") or f.endswith((".g.dart", ".freezed.dart")):
                continue
            path = os.path.join(d, f)
            text = open(path, encoding="utf-8").read()
            for m in rx.finditer(text):
                count += 1
                if m.group("path").startswith("/"):
                    line = text.count("\n", 0, m.start()) + 1
                    print("bad %s:%d: %s" % (path, line, " ".join(m.group(0).split())))
print("count %d" % count)
'
scan() { /usr/bin/python3 -I -c "$SCAN" "$@"; }

IFS=' ' read -r -a roots <<< "${MC_T0034_ROOTS:-app feature spike utility}"
existing=()
for r in "${roots[@]}"; do [[ -d "$r" ]] && existing+=("$r"); done
out="$(scan "${existing[@]}")"
hits="$(grep -a '^bad ' <<< "$out" | sed 's/^bad //')"
annotations="$(grep -a '^count ' <<< "$out" | awk '{print $2}')"

bad_cfg=""
for f in tool/bazel/config/*.json; do
  url=$(/usr/bin/python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["apiBaseUrl"])' "$f")
  [[ "$url" == */ ]] || bad_cfg+="$f ($url) "
done

# Negative controls: each sample must be reported on its own.
ctl="$(mktemp -d)"
trap 'rm -rf "$ctl"' EXIT
printf "@GET('/one')\nFuture<void> a();\n" > "$ctl/one_line.dart"
printf "@POST(\n  '/multi',\n)\nFuture<void> b();\n" > "$ctl/multi_line.dart"
printf "@DELETE(r'/raw/{id}')\nFuture<void> c();\n" > "$ctl/raw.dart"
printf '@GET( "/double" )\nFuture<void> d();\n' > "$ctl/double.dart"
printf "@GET('relative')\nFuture<void> e();\n" > "$ctl/relative_ok.dart"
ctl_out="$(scan "$ctl")"
untripped=""
for s in one_line multi_line raw double; do
  grep -q -a "/$s.dart:" <<< "$ctl_out" || untripped+="$s "
done
grep -q -a "relative_ok" <<< "$ctl_out" && untripped+="relative_ok(false positive) "

report "# T-0034-AC4: relative retrofit paths" "" \
  "- retrofit verb annotations scanned: $annotations" "" \
  "| Check | Result |" "|---|---|" \
  "| leading-slash paths | ${hits:-none} |" \
  "| config apiBaseUrl without a trailing slash | ${bad_cfg:-none} |" \
  "| negative controls (one-line, multi-line, raw, double-quoted; a relative path stays quiet) | $([[ -z "$untripped" ]] && echo 'all behave' || echo "**WRONG: $untripped**") |"
ok=1
[[ -z "$hits" ]] || ok=0
[[ -z "$bad_cfg" ]] || ok=0
[[ "${annotations:-0}" -ge 1 ]] || ok=0
[[ -z "$untripped" ]] || ok=0
finish T-0034-AC4-relative-paths $([[ $ok -eq 1 ]] && echo 0 || echo 1)
