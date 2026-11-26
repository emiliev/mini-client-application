#!/bin/bash
# T-0038 Verifier: purity negative control. Adds //utility/mc_fixtures_media to
# the mc_fixtures_comics dart_library, queries its closure for Flutter markers,
# then restores the BUILD file.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76
cd "$W" || exit 2
OUT="$W/documents/evidence/T-0038/verifier/AC4_purity_negative_control.md"
B=utility/mc_fixtures_comics/BUILD.bazel
F='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
trap 'git checkout -- "$B"' EXIT
perl -0pi -e 's|(dart_library\(\n.*?deps = \[\n)|$1        "//utility/mc_fixtures_media",\n|s' "$B"
{
  echo "# T-0038 Verifier: purity negative control"
  echo
  echo "Mutation: \`//utility/mc_fixtures_media\` added to the \`mc_fixtures_comics\` dart_library deps."
  echo '```diff'
  git diff "$B"
  echo '```'
  echo "Flutter markers in \`deps(//utility/mc_fixtures_comics:mc_fixtures_comics)\`:"
  echo '```'
  m="$(tool/bazelw --output_base=/tmp/mc-ob-T-0038-verifier cquery "deps(//utility/mc_fixtures_comics:mc_fixtures_comics)" 2>/dev/null | sed 's/ (.*//' | grep -E "$F" | sort -u | head -5)"
  echo "${m:-none}"
  echo '```'
  if [[ -n "$m" ]]; then echo "Result: markers found, the closure check would FAIL (control works)."; else echo "Result: NOT DETECTED"; fi
} > "$OUT"
cat "$OUT"
