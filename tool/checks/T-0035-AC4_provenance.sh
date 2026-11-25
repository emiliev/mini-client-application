#!/bin/bash
# T-0035-AC4: provenance of the vendored flow_builder 0.1.0.
#   1. the pub.dev archive downloads and matches the pinned sha256 (needs
#      network: a failed download is a FAIL, never a skip);
#   2. third_party/flow_builder/lib/ differs from the archive's lib/ by exactly
#      0001-forward-pushRouteInformation.patch, and LICENSE is byte-equal;
#   3. nothing still depends on the hosted copy (@pub_deps//:flow_builder);
#   4. pubspec.lock equals origin/main's minus the flow_builder block (the
#      only lock change is flow_builder's source).
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
hosted_refs=$(grep -rln --include=BUILD.bazel --include=pubspec.yaml -e '"@pub_deps//:flow_builder"' -e 'flow_builder: *\^' . 2>/dev/null | grep -v '^./bazel-' | tr '\n' ' ')
lockdiff=$(diff <(git show origin/main:pubspec.lock | awk '/^  flow_builder:$/{skip=1; next} skip&&/^  [a-z_]+:$/{skip=0} !skip' ) pubspec.lock 2>&1)
lock_rc=$?
report "# T-0035-AC4: vendored flow_builder provenance" "" "| Check | Result | Required |" "|---|---|---|" \
  "| pub.dev archive | $archive | sha256 matches |" \
  "| lib/ vs archive | $lib_diff | archive + the patch |" \
  "| LICENSE vs archive | $license | byte-equal |" \
  "| references to the hosted copy | ${hosted_refs:-none} | none |" \
  "| pubspec.lock vs origin/main minus the flow_builder block | $([[ $lock_rc -eq 0 ]] && echo identical || echo "DIFFERS: $(head -5 <<< "$lockdiff")") | identical |"
ok=1
[[ "$archive" == "sha256 matches" && "$lib_diff" == lib/* && "$license" == byte-equal ]] || ok=0
[[ -z "$hosted_refs" && $lock_rc -eq 0 ]] || ok=0
# The lock must really have lost the block (positive control for the awk).
git show origin/main:pubspec.lock | grep -q '^  flow_builder:$' || ok=0
grep -q '^  flow_builder:$' pubspec.lock && ok=0
finish T-0035-AC4-provenance $([[ $ok -eq 1 ]] && echo 0 || echo 1)
