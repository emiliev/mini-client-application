#!/bin/bash
# T-0027-AC4: the upstream PR draft exists, with a minimal repro workspace.
# Checks documents/upstream/U-D-retrofit/: README with a Conventional-Commit
# title, a `Changelog:` line (<= 100 characters), the repro, versions and a link
# to the queued patch, which must be the one MODULE.bazel applies.
# With MC_RULES_FORK=<rules_dart checkout with the patch applied>, it also runs
# the repro (`repro.sh --compare`) and requires every generated file to be EQUAL.
#   tool/checks/T-0027-AC4_upstream_draft.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
D=documents/upstream/U-D-retrofit
PATCH=0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch
has() { grep -q -- "$1" "$D/README.md" 2>/dev/null && echo yes || echo no; }
title=$(grep -c -E '^feat\(ext\): ' "$D/README.md" 2>/dev/null || true)
changelog=$(grep -E '^> Changelog: ' "$D/README.md" 2>/dev/null | head -1 | sed 's/^> Changelog: //')
patch_ok=no
[[ -f third_party/rules_patches/ai_rules_dart/$PATCH ]] && grep -q "$PATCH" MODULE.bazel && patch_ok=yes
subject=$(grep -m1 '^Subject:' "third_party/rules_patches/ai_rules_dart/$PATCH" 2>/dev/null)
run="not run (set MC_RULES_FORK)"
run_ok=1
if [[ -n "${MC_RULES_FORK:-}" ]]; then
  log="$(mktemp)"
  BAZEL="${BAZEL:-bazel}" "$REPO/$D/repro.sh" --compare "$MC_RULES_FORK" > "$log" 2>&1; rc=$?
  run="exit $rc; $(grep -c '^EQUAL' "$log") EQUAL, $(grep -c '^DIFFER' "$log") DIFFER"
  [[ $rc -eq 0 ]] || run_ok=0
  rm -f "$log"
fi
report "# T-0027-AC4: upstream draft" "" "| Check | Result |" "|---|---|" \
  "| \`$D/README.md\` / \`repro.sh\` (executable) | $([[ -f $D/README.md ]] && echo yes || echo no) / $([[ -x $D/repro.sh ]] && echo yes || echo no) |" \
  "| Conventional-Commit title line | $title |" \
  "| \`Changelog:\` line (${#changelog} chars, max 100) | \`$changelog\` |" \
  "| sections: Repro / Versions / patch link | $(has '^## Repro') / $(has '^## Versions') / $(has "$PATCH") |" \
  "| queued patch exists and MODULE.bazel applies it | $patch_ok |" \
  "| patch subject | \`$subject\` |" \
  "| repro run | $run |"
ok=1
[[ -f $D/README.md && -x $D/repro.sh && "$title" -ge 1 ]] || ok=0
[[ -n "$changelog" && ${#changelog} -le 100 && "$changelog" == *'`'* ]] || ok=0
[[ $(has '^## Repro') == yes && $(has '^## Versions') == yes && $(has "$PATCH") == yes && $patch_ok == yes ]] || ok=0
[[ $run_ok -eq 1 ]] || ok=0
finish T-0027-AC4 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
