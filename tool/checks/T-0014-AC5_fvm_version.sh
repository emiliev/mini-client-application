#!/bin/bash
# T-0014-AC5: `fvm flutter --version` inside the repo reports 3.47.7 (.fvmrc).
#   tool/checks/T-0014-AC5_fvm_version.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
want="$(/usr/bin/python3 -I -c 'import json;print(json.load(open(".fvmrc"))["flutter"])')"
got="$(fvm flutter --version 2>&1 | grep -E '^(Flutter|Tools)')"
report "# T-0014-AC5: fvm Flutter version in the repo" "" '```' "\$ fvm flutter --version   # .fvmrc pins $want" "$got" '```'
grep -q "^Flutter $want " <<< "$got" && [[ "$want" == "3.47.7" ]]
finish T-0014-AC5 $?
