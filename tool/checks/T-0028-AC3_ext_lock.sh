#!/bin/bash
# T-0028-AC3: the rules_dart ext lock (pin + patch queue, as Bazel fetched it)
# resolves analyzer 14.5.0, holds injectable 3.0.0 and no lean_builder, and the
# vendored injectable_generator has no lib/lean_builder/ and no lean_builder
# import, and that the vendored lib/ equals the pub.dev 3.1.3 archive minus
# lib/lean_builder/ (sha256-verified download; needs network, FAIL offline).
#   tool/checks/T-0028-AC3_ext_lock.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bz() { "$BAZELW" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }

# Make sure the rules repo is fetched (patched), then read it from external/.
fetch_rc=0
bz build --nobuild @rules_dart//dart/ext/injectable:shim_json > /dev/null 2>&1 || fetch_rc=$?
EXT="$(bz info output_base 2>/dev/null)/external/ai_rules_dart+"
LOCK="$EXT/dart/ext/pubspec.lock"
VEND="$EXT/dart/ext/injectable/third_party/injectable_generator"
ver() { awk -v p="  $1:" '$0==p{f=1} f&&/version:/{gsub(/"/,"",$2); print $2; exit}' "$LOCK"; }
analyzer=$(ver analyzer); injectable=$(ver injectable); lean=$(ver lean_builder)
lean_dir=$([[ -d "$VEND/lib/lean_builder" ]] && echo present || echo absent)
lean_imports=$(grep -rl "package:lean_builder" "$VEND/lib" 2>/dev/null | wc -l | tr -d ' ')
# The hub is private to rules_dart, so query it by its canonical name. The
# query must succeed and list analyzer and injectable (positive control), or
# "no lean_builder" would prove nothing.
HUB='@@ai_rules_dart++pub+ext_pub_deps'
hub_rc=0
hub_targets=$(bz query "$HUB//:all" 2>/dev/null) || hub_rc=$?
hub_ok=0
grep -qxF "$HUB//:analyzer" <<< "$hub_targets" && grep -qxF "$HUB//:injectable" <<< "$hub_targets" && hub_ok=1
lean_target=$(grep -cxF "$HUB//:lean_builder" <<< "$hub_targets" || true)

archive="NOT CHECKED (download failed; this check needs network)"
tmp="$(mktemp -d)"
if curl -sfL https://pub.dev/api/archives/injectable_generator-3.1.3.tar.gz -o "$tmp/ig.tgz"; then
  sum=$(shasum -a 256 "$tmp/ig.tgz" | cut -d' ' -f1)
  if [[ "$sum" == 24d525c60ed9abf345c8749c3291ca1b3f1d21fd53344c0c644da820a92049df ]]; then
    mkdir "$tmp/ig" && tar xzf "$tmp/ig.tgz" -C "$tmp/ig"
    rm -rf "$tmp/ig/lib/lean_builder"
    if diff -r "$tmp/ig/lib" "$VEND/lib" > "$tmp/diff" 2>&1; then archive="equal to pub.dev 3.1.3 minus lib/lean_builder/"
    else archive="DIFFERS: $(head -5 "$tmp/diff")"; fi
  else archive="DOWNLOAD SHA MISMATCH ($sum)"; fi
fi
rm -rf "$tmp"

report "# T-0028-AC3: ext lock and vendored generator" "" \
  "Fetched rules_dart (pin + queue): \`${EXT#"$(dirname "$EXT")"/}\`" "" \
  "| Check | Value | Required |" "|---|---|---|" \
  "| analyzer in dart/ext/pubspec.lock | ${analyzer:-missing} | 14.5.0 |" \
  "| injectable in dart/ext/pubspec.lock | ${injectable:-missing} | 3.0.0 |" \
  "| lean_builder in dart/ext/pubspec.lock | ${lean:-absent} | absent |" \
  "| \`bazel build --nobuild\` fetch of the patched rules | exit $fetch_rc | 0 |" \
  "| \`query $HUB//:all\` | exit $hub_rc, analyzer+injectable listed: $([[ $hub_ok -eq 1 ]] && echo yes || echo NO) | 0, yes |" \
  "| $HUB//:lean_builder target | $([[ $lean_target -gt 0 ]] && echo exists || echo absent) | absent |" \
  "| vendored lib/lean_builder/ | $lean_dir | absent |" \
  "| vendored files importing package:lean_builder | $lean_imports | 0 |" \
  "| vendored lib/ vs pub.dev archive | $archive | equal |"
ok=1
[[ "$analyzer" == 14.5.0 && "$injectable" == 3.0.0 && -z "$lean" && $lean_target -eq 0 ]] || ok=0
[[ "$lean_dir" == absent && "$lean_imports" == 0 ]] || ok=0
[[ $fetch_rc -eq 0 && $hub_rc -eq 0 && $hub_ok -eq 1 ]] || ok=0
[[ "$archive" == equal* ]] || ok=0
finish T-0028-AC3 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
