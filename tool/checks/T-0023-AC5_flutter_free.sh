#!/bin/bash
# T-0023-AC5: mc_api_errors and mc_api_client reach no Flutter and do not
# depend on mc_mocked_backend (the app wires the mock; plan 01 section 5).
#   tool/checks/T-0023-AC5_flutter_free.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
# Flutter closure markers: the sky_engine / engine repos, any pub package
# built from the Flutter SDK, and the Flutter rules. The repo name
# `ai_rules_flutter++flutter+` appears on pure-Dart targets too, so it is
# not a marker by itself.
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
rc=0
report "# T-0023-AC5: Flutter-free closure" ""
for pkg in mc_api_errors mc_api_client; do
  deps="$("$BAZELW" cquery "deps(//utility/$pkg)" 2>/dev/null | sed 's/ (.*//')"
  hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -10)"
  mocks="$(grep -E '//utility/mc_mocked_backend|@@?mc_mocked_backend' <<< "$deps" | head -3)"
  n="$(wc -l <<< "$deps" | tr -d ' ')"
  report "## $pkg ($n targets in the closure)" '```' "Flutter markers: ${hits:-none}" "mc_mocked_backend: ${mocks:-none}" '```'
  [[ -z "$deps" || -n "$hits" || -n "$mocks" ]] && rc=1
done
finish T-0023-AC5 $rc
