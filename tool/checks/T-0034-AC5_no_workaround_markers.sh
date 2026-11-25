#!/bin/bash
# T-0034-AC5: characters_list carries none of the T-0032 workarounds. Each
# marker below is a pattern the workarounds needed (F-0031); the check greps
# the hand-written lib/ and test/ sources of the feature and FAILS when any
# pattern matches, when the feature has no sources (an empty scan proves
# nothing), or when its negative control does not trip it.
#   tool/checks/T-0034-AC5_no_workaround_markers.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG="${MC_T0034_PKG:-feature/characters/characters_list}"
# name|extended regex
MARKERS=(
  "F-0031 marker comment|F-0031"
  "copyWith: false on a bloc state|copyWith: *false"
  "FlowScope.of in feature code (the build-time container read)|FlowScope\.of\("
  "container read into a local for create|\.container\b"
  "leading-slash retrofit path|@(GET|POST|PUT|PATCH|DELETE|HEAD)\( *['\"]/"
  "hand-rolled Localizations.override in the flow|Localizations\.override"
  "navigator registered in a hand-written initializer|registerSingleton<CharactersListNavigator>\(navigator\)\s*;\s*$"
  "dynamic read of a private flow widget|_LivePage"
  "dynamic .controller access|as dynamic\)\.controller"
  "word workaround|[Ww]orkaround"
)
scan() {  # scan <root> -> prints "name: file:line" for every hit
  local root="$1" name re
  for entry in "${MARKERS[@]}"; do
    name="${entry%%|*}"; re="${entry#*|}"
    grep -r -n -E --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' \
      --exclude='*.config.dart' --exclude='*_l10n*.dart' -e "$re" "$root/lib" "$root/test" 2>/dev/null |
      sed "s|^|$name: |"
  done
}
sources=$(find "$PKG/lib" "$PKG/test" -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.config.dart' ! -name '*_l10n*.dart' | wc -l | tr -d ' ')
hits="$(scan "$PKG")"

# Negative control: a copy of the feature with one marker planted must trip it.
ctl="$(mktemp -d)"
trap 'rm -rf "$ctl"' EXIT
cp -R "$PKG/lib" "$PKG/test" "$ctl/"
printf '// F-0031 workaround\n' >> "$ctl/lib/src/flow/characters_list_flow.dart"
ctl_hits="$(scan "$ctl")"

report "# T-0034-AC5: no workaround markers in $PKG" "" \
  "- Dart sources scanned: $sources" "- markers checked: ${#MARKERS[@]}" "" \
  "| Result | Detail |" "|---|---|" \
  "| hits in the feature | ${hits:-none} |" \
  "| negative control (planted marker) | $([[ -n "$ctl_hits" ]] && echo 'tripped' || echo '**NOT tripped**') |"
ok=1
[[ "$sources" -gt 10 ]] || ok=0
[[ -z "$hits" ]] || { ok=0; report "" '```' "$hits" '```'; }
[[ -n "$ctl_hits" ]] || ok=0
finish T-0034-AC5-no-markers $([[ $ok -eq 1 ]] && echo 0 || echo 1)
