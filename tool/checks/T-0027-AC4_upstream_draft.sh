#!/bin/bash
# T-0027-AC4: the upstream PR draft exists, with a minimal repro workspace.
# Checks documents/upstream/U-D-retrofit/: README with a Conventional-Commit
# title, the repro, versions and a link to the queued patch, which must be the
# one MODULE.bazel applies. The patch's commit message must carry a valid
# `Changelog:` git trailer (parsed with `git interpret-trailers --parse`,
# <= 100 characters, naming something in backticks) that equals the README's.
# With MC_RULES_FORK=<rules_dart checkout with the patch applied>, it also runs
# the repro (`repro.sh --compare`, fresh test run) with DART="fvm dart" and
# BAZEL=tool/bazelw, requires every generated file to be EQUAL, and keeps the
# log (MC_REPRO_LOG, default documents/evidence/T-0027/<role>/T-0027-AC4-repro.log).
#   tool/checks/T-0027-AC4_upstream_draft.sh [--out FILE] [--role engineer|verifier]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
D=documents/upstream/U-D-retrofit
PATCH=0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch
P="third_party/rules_patches/ai_rules_dart/$PATCH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
has() { grep -q -- "$1" "$D/README.md" 2>/dev/null && echo yes || echo no; }
title=$(grep -c -E '^feat\(ext\): ' "$D/README.md" 2>/dev/null)
readme_cl=$(grep -E '^> Changelog: ' "$D/README.md" 2>/dev/null | head -1 | sed 's/^> //')
# The commit message: the Subject line up to the first diff (export writes no `---`).
sed -n '/^Subject:/,/^diff --git/p' "$P" 2>/dev/null | sed '$d' > "$TMP/msg.txt"
trailers=$(git interpret-trailers --parse "$TMP/msg.txt")
patch_cl=$(grep -E '^Changelog: ' <<< "$trailers" | head -1)
cl_text=${patch_cl#Changelog: }
patch_ok=no
[[ -f "$P" ]] && grep -q "$PATCH" MODULE.bazel && patch_ok=yes
run="not run (set MC_RULES_FORK)"
run_ok=1
if [[ -n "${MC_RULES_FORK:-}" ]]; then
  log="${MC_REPRO_LOG:-$REPO/documents/evidence/T-0027/$ROLE/T-0027-AC4-repro.log}"
  mkdir -p "$(dirname "$log")"
  DART="fvm dart" BAZEL="$BAZELW" "$REPO/$D/repro.sh" --compare "$MC_RULES_FORK" > "$TMP/repro.raw" 2>&1; rc=$?
  { echo "# T-0027-AC4 repro run, $(date -u +%Y-%m-%dT%H:%M:%SZ): repro.sh --compare (DART=\"fvm dart\", BAZEL=tool/bazelw, test --nocache_test_results), exit $rc"
    plain "$TMP/repro.raw" | grep -a -E '^(==|EQUAL|DIFFER|ERROR|//|Executed|INFO: [0-9]+ processes|INFO: Build|  Built with)' | sed "s|$HOME|~|g"; } > "$log"
  passed=$(grep -c -E '^//:characters_api_test +PASSED' "$log")
  cached=$(grep -c -E '^//:characters_api_test +\(cached\)' "$log")
  equal=$(grep -c '^EQUAL' "$log"); differ=$(grep -c '^DIFFER' "$log")
  run="exit $rc; test PASSED (uncached) $passed, cached $cached; $equal EQUAL, $differ DIFFER; log \`${log#"$REPO"/}\`"
  [[ $rc -eq 0 && $passed -eq 1 && $cached -eq 0 && $equal -eq 3 && $differ -eq 0 ]] || run_ok=0
fi
report "# T-0027-AC4: upstream draft" "" "| Check | Result |" "|---|---|" \
  "| \`$D/README.md\` / \`repro.sh\` (executable) | $([[ -f $D/README.md ]] && echo yes || echo no) / $([[ -x $D/repro.sh ]] && echo yes || echo no) |" \
  "| Conventional-Commit title line in README | $title |" \
  "| patch trailers (\`git interpret-trailers --parse\`) | $(tr '\n' ';' <<< "$trailers") |" \
  "| \`Changelog:\` trailer (${#cl_text} chars, max 100) equals README's | $([[ -n "$patch_cl" && "$patch_cl" == "$readme_cl" ]] && echo yes || echo "no: patch \`$patch_cl\`, README \`$readme_cl\`") |" \
  "| sections: Repro / Versions / patch link | $(has '^## Repro') / $(has '^## Versions') / $(has "$PATCH") |" \
  "| queued patch exists and MODULE.bazel applies it | $patch_ok |" \
  "| repro run | $run |"
ok=1
[[ -f $D/README.md && -x $D/repro.sh && "$title" -ge 1 ]] || ok=0
[[ -n "$patch_cl" && "$patch_cl" == "$readme_cl" && ${#cl_text} -le 100 && "$cl_text" == *'`'* ]] || ok=0
[[ $(has '^## Repro') == yes && $(has '^## Versions') == yes && $(has "$PATCH") == yes && $patch_ok == yes ]] || ok=0
[[ $run_ok -eq 1 ]] || ok=0
finish T-0027-AC4 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
