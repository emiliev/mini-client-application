#!/bin/bash
# T-0035-AC4 (evergreen): provenance of the vendored flow_builder 0.1.0. It
# looks at the working tree only (never at another branch), so it can be re-run
# whenever flow_builder is re-vendored.
#   1. the pub.dev archive downloads and matches the pinned sha256 (needs
#      network: a failed download is a FAIL, never a skip);
#   2. third_party/flow_builder/lib/ differs from the archive's lib/ by exactly
#      0001-forward-pushRouteInformation.patch, and LICENSE is byte-equal;
#   3. nothing outside third_party/flow_builder uses the hosted copy:
#      - no BUILD / BUILD.bazel / *.bzl names `pub_deps//:flow_builder`, quoted
#        or not;
#      - no pubspec.yaml outside third_party/ declares flow_builder with a
#        source (`hosted:` / `git:` / `path:`) or a non-version value (a plain
#        `^0.1.0` or `any` is the workspace member's own constraint);
#      - pubspec.lock has no flow_builder entry (the workspace member is not
#        locked, a hosted copy would be).
# The one-off lock delta against the T-0035 base is T-0035-AC4_lock_delta.sh.
#   tool/checks/T-0035-AC4_provenance.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
VEND=third_party/flow_builder
SHA=9e66aa7209e9a31c347bb316abf191d2300db41cd6b7254f89abd4e76d9b3f8d
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
archive="NOT CHECKED (download failed; this check needs network)"
lib_diff="NOT CHECKED"; license="NOT CHECKED"
if curl -sfL https://pub.dev/api/archives/flow_builder-0.1.0.tar.gz -o "$tmp/fb.tgz"; then
  sum=$(shasum -a 256 "$tmp/fb.tgz" | cut -d' ' -f1)
  if [[ "$sum" == "$SHA" ]]; then
    archive="sha256 matches"
    mkdir "$tmp/a" && tar xzf "$tmp/fb.tgz" -C "$tmp/a"
    # Other lib/ files: identical. flow_builder.dart: exactly the patch.
    other=$(diff -rq -x flow_builder.dart "$tmp/a/lib" "$VEND/lib" 2>&1 || true)
    got=$(cd "$tmp/a" && diff -u lib/flow_builder.dart "$REPO/$VEND/lib/flow_builder.dart" \
      | sed -e '1s|.*|--- a/lib/flow_builder.dart|' -e '2s|.*|+++ b/lib/flow_builder.dart|')
    if [[ -n "$other" ]]; then lib_diff="DIFFERS in other files: $other"
    elif [[ -z "$got" ]]; then lib_diff="NO DIFF (the fix is missing)"
    elif [[ "$got" == "$(cat "$VEND/0001-forward-pushRouteInformation.patch")" ]]; then
      lib_diff="lib/ = archive + 0001-forward-pushRouteInformation.patch ($(grep -c '^[+-][^+-]' <<< "$got") changed lines)"
    else lib_diff="DIFFERS from the recorded patch"; fi
    cmp -s "$tmp/a/LICENSE" "$VEND/LICENSE" && license="byte-equal" || license="DIFFERS"
  else archive="SHA MISMATCH ($sum)"; fi
fi

# Hosted-copy references, outside the vendored directory and build output.
PRUNE=( \( -path ./.git -o -path "./bazel-*" -o -path ./third_party/flow_builder -o -name .dart_tool \) -prune -o )
bazel_refs=$(find . "${PRUNE[@]}" -type f \( -name BUILD -o -name BUILD.bazel -o -name '*.bzl' \) \
  -exec grep -l 'pub_deps//:flow_builder' {} + 2>/dev/null | tr '\n' ' ')
pubspec_refs=$(find . "${PRUNE[@]}" -type f -name pubspec.yaml -exec /usr/bin/python3 -I -c '
import re, sys
ok = re.compile(r"^(\^?[0-9][0-9.]*|any|\"[^\"]*\"|\x27[^\x27]*\x27)\s*(#.*)?$")
for path in sys.argv[1:]:
    for line in open(path):
        m = re.match(r"^\s*flow_builder:\s*(.*?)\s*$", line)
        if m and not ok.match(m.group(1)):
            print(path); break
' {} + 2>/dev/null | tr '\n' ' ')
lock_ref=$(grep -c '^  flow_builder:$' pubspec.lock || true)
report "# T-0035-AC4: vendored flow_builder provenance (evergreen)" "" "| Check | Result | Required |" "|---|---|---|" \
  "| pub.dev archive | $archive | sha256 matches |" \
  "| lib/ vs archive | $lib_diff | archive + the patch |" \
  "| LICENSE vs archive | $license | byte-equal |" \
  "| BUILD / BUILD.bazel / *.bzl naming \`pub_deps//:flow_builder\` | ${bazel_refs:-none} | none |" \
  "| pubspec.yaml declaring flow_builder with a source | ${pubspec_refs:-none} | none |" \
  "| flow_builder entries in pubspec.lock | $lock_ref | 0 |"
ok=1
[[ "$archive" == "sha256 matches" && "$lib_diff" == lib/* && "$license" == byte-equal ]] || ok=0
[[ -z "$bazel_refs" && -z "$pubspec_refs" && "$lock_ref" == 0 ]] || ok=0
finish T-0035-AC4-provenance $([[ $ok -eq 1 ]] && echo 0 || echo 1)
