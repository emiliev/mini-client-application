#!/bin/bash
# T-0074-AC1: the Bazel graph of the tree, for a before/after comparison of a
# BUILD normalisation (`mcgen buildgen --adopt`). Writes into DIR:
#   deps.txt         `bazel query 'deps(//...)'`, sorted: every target and
#                    file the build reaches (the task's literal check)
#   label_kind.txt   the same with each target's rule kind
#   edges.txt        `deps(//...)` as `from -> to` edges, sorted
#   build.txt        `bazel query '//...' --output=build` with the parts that
#                    name a BUILD file line (location comments,
#                    generator_location) dropped and every list's items
#                    sorted: each in-repo target's attributes, which an edit
#                    that only reorders lists or statements leaves equal
#   tool/mcgen/tool/T-0074-AC1_graph.sh DIR
# MC_BAZEL_STARTUP (e.g. "--output_base=/tmp/mc-ob-T-0074-engineer") picks the
# Bazel server, as for every tool/checks script.
set -euo pipefail
out="$(mkdir -p "${1:?usage: $0 DIR}" && cd "$1" && pwd)"
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
read -r -a MC_STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bzw() { tool/bazelw ${MC_STARTUP[@]+"${MC_STARTUP[@]}"} "$@"; }
bzw query 'deps(//...)' 2>/dev/null | LC_ALL=C sort > "$out/deps.txt"
bzw query 'deps(//...)' --output=label_kind 2>/dev/null | LC_ALL=C sort > "$out/label_kind.txt"
bzw query 'deps(//...)' --output=graph --nograph:factored 2>/dev/null \
  | sed -n 's/^  "\(.*\)" -> "\(.*\)"$/\1 -> \2/p' | LC_ALL=C sort > "$out/edges.txt"
bzw query '//...' --output=build 2>/dev/null \
  | python3 -I -c '
import re, sys
text = sys.stdin.read()
text = re.sub(r"^#.*\n", "", text, flags=re.M)
text = re.sub(r"^  generator_location = .*\n", "", text, flags=re.M)
def sort_lists(m):
    items = [i.strip() for i in m.group(1).split(", ") if i.strip()]
    return "[" + ", ".join(sorted(items)) + "]"
text = re.sub(r"\[([^\[\]]*)\]", sort_lists, text)
rules = [r.strip() for r in text.split("\n\n") if r.strip()]
print("\n\n".join(sorted(rules)))
' > "$out/build.txt"
wc -l "$out"/*.txt
