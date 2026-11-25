#!/bin/bash
# T-0032-AC6: the build_runner overlay helpers read pubspecs correctly, so the
# byte-identity references resolve the same packages Bazel builds with.
#   - overlay_deps.py: a blank line or a comment inside `dependencies:` does
#     not end the block; `dev_dependencies:` and SDK packages are not deps.
#   - add_dep.py: a package listed only under `dev_dependencies:` is still
#     added to `dependencies:`; one already there is not added twice.
#   tool/checks/T-0032-AC6_overlay_tools.sh [--out FILE] [--role R]
# MC_OVERLAY_TOOLS points at another copy of the two scripts (a negative run).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
TOOLS="${MC_OVERLAY_TOOLS:-$REPO/tool/build_runner_overlay}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/a" "$work/b"
printf 'name: ws\nworkspace:\n  - a\n  - b\n' > "$work/pubspec.yaml"
printf 'name: b\nresolution: workspace\n' > "$work/b/pubspec.yaml"
cat > "$work/a/pubspec.yaml" <<'EOF'
name: a
resolution: workspace

dependencies:
  b: any

  # hosted packages
  dio: ^5.11.0
  flutter:
    sdk: flutter

dev_dependencies:
  test: ^1.25.0
EOF
deps=$(/usr/bin/python3 -I "$TOOLS/overlay_deps.py" "$work" a 2>&1)
want=$'first\tb\tb\nhosted\tdio'
deps_ok=0; [[ "$deps" == "$want" ]] && deps_ok=1

cat > "$work/over.yaml" <<'EOF'
name: o
dependencies:
  dio: any

dev_dependencies:
  mocktail: any
EOF
/usr/bin/python3 -I "$TOOLS/add_dep.py" "$work/over.yaml" mocktail 2>&1
/usr/bin/python3 -I "$TOOLS/add_dep.py" "$work/over.yaml" dio 2>&1
in_deps=$(awk '/^dependencies:/{f=1;next} /^[a-z_]+:/{f=0} f' "$work/over.yaml")
add_ok=0
[[ $(grep -c '^  mocktail: any$' <<< "$in_deps") -eq 1 && $(grep -c '^  dio: any$' <<< "$in_deps") -eq 1 ]] && add_ok=1

report "# T-0032-AC6: overlay helpers parse pubspec blocks" "" \
  "Scripts: \`${TOOLS#"$REPO"/}\`" "" \
  "| Case | Result |" "|---|---|" \
  "| overlay_deps.py over a block with a blank line and a comment | $([[ $deps_ok -eq 1 ]] && echo ok || echo "WRONG: $(tr '\n\t' '; ' <<< "$deps")") |" \
  "| add_dep.py adds a dev-only package to dependencies, once; keeps dio once | $([[ $add_ok -eq 1 ]] && echo ok || echo "WRONG: $(tr '\n' ';' <<< "$in_deps")") |"
finish T-0032-AC6-overlay-tools $([[ $deps_ok -eq 1 && $add_ok -eq 1 ]] && echo 0 || echo 1)
