#!/bin/bash
# Verifier positive controls for T-0032-AC6 cutoff: signature edits MUST re-run
# what depends on them. Edits get a unique token so no cache can answer.
#   sigedit.sh <outdir>   (run from the repo root)
set -uo pipefail
OUT="$1"; mkdir -p "$OUT"
OB=--output_base=/tmp/mc-ob-T-0032-verifier
bz() { tool/bazelw "$OB" "$@"; }
PKG=feature/characters/characters_list
TARGET=//$PKG:characters_list
BIN="$(bz info bazel-bin 2>/dev/null)/$PKG/lib/src"
tok="v$(date +%s)$$"

spawns() { /usr/bin/python3 -I - "$1" <<'EOF'
import json, sys
text = open(sys.argv[1]).read()
dec, i = json.JSONDecoder(), 0
while i < len(text):
    while i < len(text) and text[i].isspace(): i += 1
    if i >= len(text): break
    s, i = dec.raw_decode(text, i)
    print(f"{s.get('mnemonic')}\t{s.get('targetLabel')}\tcacheHit={s.get('cacheHit', False)}")
EOF
}

run_case() {  # name file old new
  local name="$1" file="$2" old="$3" new="$4"
  cp "$file" "$OUT/$name.orig"
  bz build --remote_download_all "$TARGET" > "$OUT/$name.b0.log" 2>&1 || { echo "$name: baseline build FAILED"; return; }
  local c0 a0; c0=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -c1-16); a0=$(shasum -a 256 "$BIN/domain/api/characters_list_api.g.dart" | cut -c1-16)
  /usr/bin/python3 -I - "$file" "$old" "$new" <<'EOF'
import sys
p, old, new = sys.argv[1:4]
s = open(p).read(); assert s.count(old) == 1, old
open(p, "w").write(s.replace(old, new))
EOF
  bz build --remote_download_all --output_groups=-dart_analyze,-dart_format --execution_log_json_file="$OUT/$name.exec.json" "$TARGET" > "$OUT/$name.b1.log" 2>&1; local rc=$?
  local c1 a1; c1=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -c1-16); a1=$(shasum -a 256 "$BIN/domain/api/characters_list_api.g.dart" | cut -c1-16)
  cp "$OUT/$name.orig" "$file"
  spawns "$OUT/$name.exec.json" > "$OUT/$name.spawns.tsv"
  echo "== $name (build rc=$rc)"
  echo "config.dart  $c0 -> $c1"
  echo "api .g.dart  $a0 -> $a1"
  grep -E 'DartAggregateCodegen|retrofit_part|_characters_list_api_g|_inj|_freezed' "$OUT/$name.spawns.tsv"
}

# A: the API's method signature (a new query parameter): retrofit must re-run;
#    the API shard and the aggregate need not (the factory is unchanged).
run_case api_signature "$PKG/lib/src/domain/api/characters_list_api.dart" \
  "    @Query('team') String? team," \
  "    @Query('team') String? team,
    @Query('$tok') String? $tok,"

# B: an injectable constructor signature (the repository gains a root
#    dependency): its shard changes, so the aggregate MUST re-run and
#    .config.dart must change.
run_case ctor_signature "$PKG/lib/src/domain/repository/characters_list_repository.dart" \
  "  CharactersListRepository(this._api);" \
  "  CharactersListRepository(this._api, {@Named('$tok') String? $tok});"

bz build "$TARGET" > /dev/null 2>&1
echo restored
