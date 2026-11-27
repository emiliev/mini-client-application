#!/bin/bash
# T-0064-AC7: a body edit in a trivia_quiz bloc (the play bloc's round
# start) re-runs neither the injectable aggregate (:di_config) nor the
# retrofit part of the API, nor the DTO's json part. Same shape as
# T-0032-AC6_cutoff.sh.
#
# The edit is a statement in the body of `_load` with a unique token, then
# `build :trivia_quiz` with --execution_log_json_file. PASS needs:
#   - positive controls: the bloc's freezed action and its injectable shard
#     really executed (cacheHit=False), so the edit reached the generators;
#   - no DartAggregateCodegen spawn that is not a cache hit, and the
#     .config.dart byte-identical;
#   - no executed spawn for the retrofit part, the API combine or the DTO
#     json part, and the API .g.dart byte-identical;
#   - structurally (aquery): the bloc file is not an input of the retrofit or
#     the aggregate action.
#   tool/checks/T-0064-AC7_cutoff.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG=feature/trivia/trivia_quiz
SRC="$PKG/lib/src/presentation/bloc/trivia_play_bloc.dart"
TARGET="//$PKG:trivia_quiz"
work="$(mktemp -d)"
cp "$SRC" "$work/orig.dart"
restore() { cp "$work/orig.dart" "$SRC"; }
trap 'restore; rm -rf "$work"' EXIT

bzw build --remote_download_all "$TARGET" > "$work/b0.log" 2>&1 || { plain "$work/b0.log" | tail -20; finish T-0064-AC7-cutoff 1; }
BIN="$(bzw info bazel-bin 2>/dev/null)/$PKG/lib/src"
config0=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -d' ' -f1)
api0=$(shasum -a 256 "$BIN/domain/api/trivia_quiz_api.g.dart" | cut -d' ' -f1)

token="cutoff-$(date +%s)-$$"
/usr/bin/python3 -I - "$SRC" "$token" <<'EOF'
import sys
p, tok = sys.argv[1], sys.argv[2]
s = open(p).read()
old = "      _tracker.roundStarted(round.category, round.difficulty.name);\n"
assert s.count(old) == 1, "body to edit not found"
open(p, "w").write(s.replace(old, old + "      assert('" + tok + "'.isNotEmpty);\n"))
EOF
bzw build --remote_download_all --execution_log_json_file="$work/exec.json" "$TARGET" > "$work/b1.log" 2>&1 \
  || { plain "$work/b1.log" | tail -20; finish T-0064-AC7-cutoff 1; }
config1=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -d' ' -f1)
api1=$(shasum -a 256 "$BIN/domain/api/trivia_quiz_api.g.dart" | cut -d' ' -f1)
spawns=$(/usr/bin/python3 -I - "$work/exec.json" <<'EOF'
import json, sys
text = open(sys.argv[1]).read()
dec, i = json.JSONDecoder(), 0
while i < len(text):
    while i < len(text) and text[i].isspace(): i += 1
    if i >= len(text): break
    s, i = dec.raw_decode(text, i)
    print(f"{s.get('mnemonic')}\t{s.get('targetLabel')}\tcacheHit={s.get('cacheHit', False)}\texitCode={s.get('exitCode', 0)}")
EOF
)
[[ -n "$OUT" ]] && mkdir -p "$(dirname "$OUT")" && printf '%s\n' "$spawns" > "${OUT%.md}-spawns.tsv"
TAB=$'\t'
ran() { printf '%s\n' "$spawns" | grep -a -E "^$1${TAB}[^${TAB}]*:$2${TAB}cacheHit=False${TAB}exitCode=0$" || true; }
bloc_freezed=$(ran DartCodegen _play_bloc_freezed)
bloc_shard=$(ran DartCodegen '_di_config_[a-z_]*trivia_play_bloc_inj')
agg_miss=$(printf '%s\n' "$spawns" | grep -a '^DartAggregateCodegen' | grep -av $'\tcacheHit=True\t' || true)
retrofit_runs=$(printf '%s\n' "$spawns" | grep -a -E $'\t[^\t]*:(_trivia_quiz_api_retrofit_part|_trivia_quiz_api_g|_trivia_dto_json_part)\t' | grep -av $'\tcacheHit=True\t' || true)

inputs_of() {  # <mnemonic> <target>: the package-local inputs of that action
  bzw aquery "mnemonic($1, $2)" --output=jsonproto 2>/dev/null | /usr/bin/python3 -I -c '
import json, sys
d = json.load(sys.stdin)
arts = {a["id"]: a["pathFragmentId"] for a in d.get("artifacts", [])}
frags = {f["id"]: f for f in d.get("pathFragments", [])}
def path(fid):
    parts = []
    while fid:
        f = frags[fid]; parts.append(f["label"]); fid = f.get("parentId")
    return "/".join(reversed(parts))
sets = {s["id"]: s for s in d.get("depSetOfFiles", [])}
def files(sid, seen):
    if sid in seen: return []
    seen.add(sid); s = sets[sid]; out = [path(arts[a]) for a in s.get("directArtifactIds", [])]
    for t in s.get("transitiveDepSetIds", []): out += files(t, seen)
    return out
for a in d.get("actions", []):
    seen, all_ = set(), []
    for sid in a.get("inputDepSetIds", []): all_ += files(sid, seen)
    for p in sorted(set(all_)):
        if "feature/trivia/trivia_quiz/lib/" in p: print(p)
'
}
retrofit_inputs=$(inputs_of DartCodegen "//$PKG:_trivia_quiz_api_retrofit_part")
agg_inputs=$(inputs_of DartAggregateCodegen "//$PKG:di_config")
bloc_in_retrofit=$(grep -c 'presentation/bloc/' <<< "$retrofit_inputs")
bloc_in_agg=$(grep -c 'trivia_play_bloc.dart' <<< "$agg_inputs")

report "# T-0064-AC7: a bloc body edit cuts off before retrofit and the injectable aggregate" "" \
  "Edit: \`assert('$token'.isNotEmpty);\` added to the round start of \`TriviaPlayBloc._load\` in \`$SRC\`, then \`build $TARGET\` with \`--execution_log_json_file\`." "" \
  "| | before | after |" "|---|---|---|" \
  "| di_initializer.config.dart sha256 | \`${config0:0:16}\` | \`${config1:0:16}\` |" \
  "| trivia_quiz_api.g.dart sha256 | \`${api0:0:16}\` | \`${api1:0:16}\` |" "" \
  "| Check | Result |" "|---|---|" \
  "| positive control: bloc freezed action executed | $([[ -n "$bloc_freezed" ]] && echo yes || echo NO) |" \
  "| positive control: bloc injectable shard executed | $([[ -n "$bloc_shard" ]] && echo yes || echo NO) |" \
  "| aggregate spawns that were not cache hits | ${agg_miss:-none} |" \
  "| retrofit part / API combine / DTO json spawns that ran | ${retrofit_runs:-none} |" \
  "| bloc files among the retrofit action's inputs | $bloc_in_retrofit |" \
  "| bloc file among the aggregate action's inputs | $bloc_in_agg |" "" \
  "Spawns in the execution log after the edit:" "" '```' "$spawns" '```' "" \
  "Package-local inputs of the aggregate action (aquery):" "" '```' "$agg_inputs" '```'
ok=1
[[ -n "$spawns" && -n "$bloc_freezed" && -n "$bloc_shard" ]] || ok=0
[[ -z "$agg_miss" && -z "$retrofit_runs" ]] || ok=0
[[ "$config0" == "$config1" && "$api0" == "$api1" ]] || ok=0
[[ -n "$retrofit_inputs" && -n "$agg_inputs" && $bloc_in_retrofit -eq 0 && $bloc_in_agg -eq 0 ]] || ok=0
restore
bzw build "$TARGET" > /dev/null 2>&1 || true
finish T-0064-AC7-cutoff $([[ $ok -eq 1 ]] && echo 0 || echo 1)
