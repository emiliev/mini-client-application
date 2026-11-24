#!/bin/bash
# T-0028-AC4: a file the annotation scan marks injectable but that yields no
# dependencies gets the shard `[]`, and the config stage still succeeds; an
# @InjectableInit file that generates nothing fails the build instead of
# writing an empty .config.dart (two manual targets in spike/di_sample).
#   tool/checks/T-0028-AC4_empty_shard_and_failing_init.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bz() { "$BAZELW" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }
PKG=spike/di_sample
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

bz build --remote_download_all "//$PKG:di_config" > "$work/ok.log" 2>&1; ok_rc=$?
BIN="$(bz info bazel-bin 2>/dev/null)/$PKG"
shard="$(cat "$BIN/lib/src/plain_helper.injectable.json" 2>/dev/null || echo MISSING)"
config_bytes=$(wc -c < "$BIN/lib/src/di/di_initializer.config.dart" 2>/dev/null | tr -d ' ')

bz build "//$PKG:di_config_without_init" > "$work/noinit.log" 2>&1; noinit_rc=$?
noinit_msg=$(plain "$work/noinit.log" | grep -a -o 'injectable config: .*generated nothing for [^ ]*' | head -1)
noinit_out=$([[ -e "$BIN/testdata/di_without_init.config.dart" ]] && echo written || echo "not written")

bz build "//$PKG:di_config_unresolved_init" > "$work/unres.log" 2>&1; unres_rc=$?
unres_msg=$(plain "$work/unres.log" | grep -a -o 'Could not resolve annotation for .*' | head -1)
unres_out=$([[ -e "$BIN/lib/src/di/unresolved/di_initializer.config.dart" ]] && echo written || echo "not written")

report "# T-0028-AC4: empty shard, and an init that generates nothing" "" \
  "| Case | Result |" "|---|---|" \
  "| \`plain_helper.dart\` (\"@injectable\" only in a comment): shard | \`$shard\` |" \
  "| \`:di_config\` with that shard | exit $ok_rc, .config.dart $config_bytes bytes |" \
  "| \`:di_config_without_init\` (no @InjectableInit) | exit $noinit_rc, output $noinit_out; \`$noinit_msg\` |" \
  "| \`:di_config_unresolved_init\` (package:injectable not in deps) | exit $unres_rc, output $unres_out; \`$unres_msg\` |" "" \
  "Unit tests: \`@rules_dart//dart/ext/injectable:injectable_shims_test\` (T-0028-AC4 cases) and \`//$PKG:di_sample_test\`."
ok=1
[[ $ok_rc -eq 0 && "$shard" == "[]" && "${config_bytes:-0}" -gt 0 ]] || ok=0
[[ $noinit_rc -ne 0 && -n "$noinit_msg" && "$noinit_out" == "not written" ]] || ok=0
[[ $unres_rc -ne 0 && -n "$unres_msg" && "$unres_out" == "not written" ]] || ok=0
finish T-0028-AC4 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
