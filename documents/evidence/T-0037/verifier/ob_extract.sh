#!/bin/bash
# The gates script's extraction (T-0036-AC3_gates.sh mutations()), under /bin/bash 3.2.
for v in "--output_base=/tmp/a" "--host_jvm_args=-Xmx2g --output_base=/tmp/b --batch" "--batch" "--output_base=/tmp/c"$'\t'"--x"; do
  MC_BAZEL_STARTUP="$v"; ob=""
  [[ "$MC_BAZEL_STARTUP" =~ --output_base=([^[:space:]]+) ]] && ob="${BASH_REMATCH[1]}"
  echo "[$v] -> [$ob]"
done
echo "bash $BASH_VERSION"
