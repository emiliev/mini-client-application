#!/bin/bash
# Verifier re-verification batch at 1d5e74a; run from the repo root.
R=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/r
OB=--output_base=/tmp/mc-ob-T-0032-verifier
export MC_BAZEL_STARTUP=$OB
P=feature/characters/characters_list
bz() { tool/bazelw $OB "$@"; }

# 11: double-quoted export in the barrel, and a double-quoted Flutter import in a pure file
B=$P/lib/characters_list.dart; N=$P/lib/src/navigator/characters_list_navigator.dart
cp $B $R/barrel.orig; cp $N $R/nav.orig
printf 'export "package:characters_list/src/presentation/bloc/characters_list_bloc.dart"\n    show CharactersListBloc;\n' >> $B
bz test --nocache_test_results --output_groups=-dart_analyze,-dart_format //$P:architecture_test > $R/arch_dq_export.log 2>&1; echo "arch double-quoted export rc=$?"
bz run //tool/mc_arch_check:bin > $R/archcheck_dq_export.log 2>&1; echo "mc_arch_check double-quoted export rc=$?"
cp $R/barrel.orig $B
printf 'import "package:flutter/foundation.dart" show kDebugMode;\n' | cat - $R/nav.orig > $N
bz test --nocache_test_results --output_groups=-dart_analyze,-dart_format //$P:architecture_test > $R/arch_dq_import.log 2>&1; echo "arch double-quoted flutter import rc=$?"
cp $R/nav.orig $N

# AC6 checks
tool/checks/T-0032-AC6_matches_build_runner.sh --out $R/byte_identity.md --role verifier > $R/byte.log 2>&1; echo "byte identity rc=$?"
tool/checks/T-0032-AC6_cutoff.sh --out $R/cutoff.md --role verifier > $R/cutoff.log 2>&1; echo "cutoff rc=$?"
tool/checks/T-0032-AC6_generated_not_committed.sh --out $R/notcommitted.md --role verifier > $R/notcommitted.log 2>&1; echo "not committed rc=$?"
tool/checks/T-0032-AC6_overlay_tools.sh --out $R/overlay_new.md --role verifier > $R/overlay_new.log 2>&1; echo "overlay tools (new) rc=$?"
MC_OVERLAY_TOOLS=$R/oldtools tool/checks/T-0032-AC6_overlay_tools.sh --out $R/overlay_old.md --role verifier > $R/overlay_old.log 2>&1; echo "overlay tools (old c3a5e82 scripts) rc=$?"

# AC7 gates, normal
tool/checks/T-0032-AC7_gates.sh --out $R/gates.md --role verifier > $R/gates.log 2>&1; echo "AC7 gates rc=$?"
# my own coverage parse over the same coverage run
TL=$(bz info bazel-testlogs 2>/dev/null)/$P
python3 -I $R/../v/cov.py package:characters_list/ $P/lib $TL/*/coverage.dat > $R/coverage.txt 2>&1; echo "my coverage parse rc=$?"

# AC7 gates, forced coverage miss: 20 uncovered lines in a lib file, default threshold 90
F=$P/lib/src/presentation/widget/failure_message.dart
cp $F $R/fm.orig
{
  printf '\n/// Verifier probe: never called (forced coverage miss).\nint verifierUncovered(int x) {\n  var y = x;\n'
  for i in $(seq 1 19); do printf '  y += %d;\n' "$i"; done
  printf '  return y;\n}\n'
} >> $F
tool/checks/T-0032-AC7_gates.sh --out $R/gates_forced_miss.md --role verifier > $R/gates_forced_miss.log 2>&1; echo "AC7 gates forced miss rc=$?"
cp $R/fm.orig $F
bz build //$P:characters_list > /dev/null 2>&1
echo done
