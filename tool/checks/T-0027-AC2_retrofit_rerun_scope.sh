#!/bin/bash
# T-0027-AC2: a body edit in the @RestApi file (no signature change) reruns only
# that file's retrofit, combine and compile/analysis actions. Edits
# spike/retrofit_api/lib/src/characters_api.dart and always restores it.
#
# Method: test the two spike packages once (warm), then edit the body of the
# hand-written extension and test again. Both builds use the same flags (disk
# cache off, a JSON execution log): changing --disk_cache between them makes
# Bazel rerun everything. Action-cache hits are not logged, so the second log
# lists exactly the spawns that had to run. PASS when:
#   - the DartCodegen spawns are exactly the API file's retrofit part and its
#     combine (once per configuration: the test's transition duplicates them, X9);
#   - the retrofit shard is byte-identical before and after (the edit is outside the
#     @RestApi class), so retrofit's own output cuts off;
#   - no spawn belongs to //spike/api_envelope, and no codegen spawn to character_dto;
#   - both builds pass.
#   tool/checks/T-0027-AC2_retrofit_rerun_scope.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
SRC=spike/retrofit_api/lib/src/characters_api.dart
TARGETS=(//spike/retrofit_api/... //spike/api_envelope/...)
TMP="$(mktemp -d)"
cp "$SRC" "$TMP/api.orig"
restore() { cp "$TMP/api.orig" "$REPO/$SRC"; }
trap 'restore; rm -rf "$TMP"' EXIT

BIN="$("$BAZELW" info bazel-bin 2>/dev/null)/spike/retrofit_api/lib/src"
FLAGS=(--remote_download_all --disk_cache=)
"$BAZELW" test "${FLAGS[@]}" --execution_log_json_file="$TMP/exec0.json" "${TARGETS[@]}" > "$TMP/before.log" 2>&1; rc0=$?
shard0=$(shasum -a 256 "$BIN/characters_api.retrofit.g.part" 2>/dev/null | cut -c1-16)
g0=$(shasum -a 256 "$BIN/characters_api.g.dart" 2>/dev/null | cut -c1-16)

# Body-only edit: a different argument inside firstPage(); every signature stays.
nonce="$(date +%s)"
sed -i '' "s/getCharacters(limit: 30, team: team);/getCharacters(limit: 30 + 0 * $nonce, team: team);/" "$SRC"
grep -q "0 \* $nonce" "$SRC" || { report "edit did not apply"; finish T-0027-AC2 1; }
"$BAZELW" test "${FLAGS[@]}" --execution_log_json_file="$TMP/exec.json" "${TARGETS[@]}" > "$TMP/after.log" 2>&1; rc1=$?
shard1=$(shasum -a 256 "$BIN/characters_api.retrofit.g.part" 2>/dev/null | cut -c1-16)
g1=$(shasum -a 256 "$BIN/characters_api.g.dart" 2>/dev/null | cut -c1-16)
restore

/usr/bin/python3 -I - "$TMP/exec.json" > "$TMP/spawns.txt" <<'EOF'
import json, sys
dec, buf = json.JSONDecoder(), open(sys.argv[1]).read()
i, rows = 0, []
while True:
    while i < len(buf) and buf[i].isspace():
        i += 1
    if i >= len(buf):
        break
    obj, i = dec.raw_decode(buf, i)
    outs = [o.get("path", "") for o in obj.get("actualOutputs", obj.get("listedOutputs", []))]
    out = next((o for o in outs if not o.endswith(".params")), outs[0] if outs else "")
    rows.append((obj.get("mnemonic", "?"), obj.get("targetLabel", "?"), "cachehit" if obj.get("cacheHit") else "ran", out.split("/bin/")[-1]))
for r in sorted(rows):
    print("\t".join(r))
EOF

codegen=$(awk -F'\t' '$1=="DartCodegen"{print $4}' "$TMP/spawns.txt" | sort -u | tr '\n' ' ')
envelope=$(grep -c $'\t//spike/api_envelope' "$TMP/spawns.txt" || true)
dto_codegen=$(awk -F'\t' '$1=="DartCodegen" && $4 ~ /character_dto/' "$TMP/spawns.txt" | wc -l | tr -d ' ')
total=$(wc -l < "$TMP/spawns.txt" | tr -d ' ')

report "# T-0027-AC2: rerun scope of a body edit in the @RestApi file" "" \
  "Edit: \`firstPage()\` body in \`$SRC\` (\`limit: 30\` -> \`limit: 30 + 0 * $nonce\`); no signature changes." "" \
  "| Check | Result |" "|---|---|" \
  "| build before / after the edit | exit $rc0 / $rc1 |" \
  "| spawns executed after the edit (disk cache off; action-cache hits are not logged) | $total |" \
  "| DartCodegen spawns | \`$codegen\` |" \
  "| \`characters_api.retrofit.g.part\` before / after | \`$shard0\` / \`$shard1\` |" \
  "| \`characters_api.g.dart\` before / after | \`$g0\` / \`$g1\` |" \
  "| spawns in //spike/api_envelope | $envelope |" \
  "| codegen spawns for character_dto | $dto_codegen |" "" \
  "Spawns by mnemonic:" "" '```' "$(cut -f1 "$TMP/spawns.txt" | sort | uniq -c)" '```' "" \
  "Every spawn (mnemonic, target, cache, primary output):" "" '```' "$(cat "$TMP/spawns.txt")" '```'
ok=1
[[ $rc0 -eq 0 && $rc1 -eq 0 ]] || ok=0
[[ "$codegen" == "spike/retrofit_api/lib/src/characters_api.g.dart spike/retrofit_api/lib/src/characters_api.retrofit.g.part " ]] || ok=0
[[ -n "$shard0" && "$shard0" == "$shard1" && "$g0" == "$g1" ]] || ok=0
[[ "$envelope" -eq 0 && "$dto_codegen" -eq 0 ]] || ok=0
finish T-0027-AC2 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
