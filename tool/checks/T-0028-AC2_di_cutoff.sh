#!/bin/bash
# T-0028-AC2 (H-DI-CUTOFF): a method-body edit that doesn't change DI re-runs
# only that file's shard action; the shard comes out byte-identical and the
# injectable aggregate action (:di_config) is not executed (an action-cache
# hit: no spawn in the execution log, or a spawn with cacheHit). Also lists
# the aggregate's package-local inputs from aquery: only the init file and the
# shards (V3-04, P3-04).
#   tool/checks/T-0028-AC2_di_cutoff.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bz() { "$BAZELW" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }
PKG=spike/di_sample
SRC="$PKG/lib/src/greeting_repository.dart"
TARGET="//$PKG:di_config"
work="$(mktemp -d)"
cp "$SRC" "$work/orig.dart"
restore() { cp "$work/orig.dart" "$SRC"; }
trap 'restore; rm -rf "$work"' EXIT

bz build --remote_download_all "$TARGET" > "$work/b0.log" 2>&1 || { plain "$work/b0.log" | tail -20; finish T-0028-AC2 1; }
BIN="$(bz info bazel-bin 2>/dev/null)/$PKG/lib/src"
shard0=$(shasum -a 256 "$BIN/greeting_repository.injectable.json" | cut -d' ' -f1)
config0=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -d' ' -f1)

# Body edit with a unique token, so the shard action really executes (no disk-cache hit).
token="cutoff-$(date +%s)-$$"
/usr/bin/python3 -I - "$SRC" "$token" <<'EOF'
import sys
p, tok = sys.argv[1], sys.argv[2]
s = open(p).read()
old = "'Hello $name from $_appName at ${_hour()}'"
assert old in s, "body to edit not found"
open(p, "w").write(s.replace(old, "'Hello $name from $_appName at ${_hour()} (" + tok + ")'"))
EOF
bz build --remote_download_all --execution_log_json_file="$work/exec.json" "$TARGET" > "$work/b1.log" 2>&1 \
  || { plain "$work/b1.log" | tail -20; finish T-0028-AC2 1; }
# Keep the spawn list (mnemonic, target, cacheHit, outputs) next to the report.
[[ -n "$OUT" ]] && mkdir -p "$(dirname "$OUT")" && /usr/bin/python3 -I - "$work/exec.json" > "${OUT%.md}-execlog.json" <<'EOF2'
import json, sys
text = open(sys.argv[1]).read()
dec, i, out = json.JSONDecoder(), 0, []
while i < len(text):
    while i < len(text) and text[i].isspace(): i += 1
    if i >= len(text): break
    obj, i = dec.raw_decode(text, i)
    out.append({k: obj.get(k) for k in ("mnemonic", "targetLabel", "cacheHit", "remotable", "exitCode", "status", "runner")} | {"actualOutputs": [o.get("path") for o in obj.get("actualOutputs", [])]})
json.dump(out, sys.stdout, indent=1)
EOF2
shard1=$(shasum -a 256 "$BIN/greeting_repository.injectable.json" | cut -d' ' -f1)
config1=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -d' ' -f1)
spawns=$(/usr/bin/python3 -I - "$work/exec.json" <<'EOF'
import json, sys
text = open(sys.argv[1]).read()
dec, i, out = json.JSONDecoder(), 0, []
while i < len(text):
    while i < len(text) and text[i].isspace(): i += 1
    if i >= len(text): break
    obj, i = dec.raw_decode(text, i)
    out.append(obj)
for s in out:
    print(f"{s.get('mnemonic')}\t{s.get('targetLabel')}\tcacheHit={s.get('cacheHit', False)}\texitCode={s.get('exitCode', 0)}")
EOF
)
agg=$(printf '%s\n' "$spawns" | grep -a '^DartAggregateCodegen' || true)
# The edited file's shard must really execute (not a cache hit), or the run
# proves nothing about the cutoff.
shard_run=$(printf '%s\n' "$spawns" | grep -a -E $'^DartCodegen\t[^\t]*greeting_repository_inj\tcacheHit=False\texitCode=0$' || true)
# Every aggregate spawn (if any) must be a cache hit.
agg_miss=$(printf '%s\n' "$spawns" | grep -a '^DartAggregateCodegen' | grep -av $'\tcacheHit=True\t' || true)
inputs=$(bz aquery "mnemonic(DartAggregateCodegen, $TARGET)" --output=jsonproto 2>/dev/null | /usr/bin/python3 -I -c '
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
        if "spike/di_sample/" in p and ".pkg_roots." not in p and not p.endswith((".package_config.json", ".params")): print(p)
')
local_inputs_ok=1
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  [[ "$p" == *"lib/src/di/di_initializer.dart" || "$p" == *".injectable.json" || "$p" == *"/di_config"* ]] || local_inputs_ok=0
done <<< "$inputs"

report "# T-0028-AC2: injectable early cutoff (H-DI-CUTOFF)" "" \
  "Edit: method body of \`$SRC\` (\`greeting()\` string; token \`$token\`), then \`build $TARGET\` with \`--execution_log_json_file\`." "" \
  "| | before | after |" "|---|---|---|" \
  "| greeting_repository.injectable.json sha256 | \`${shard0:0:16}\` | \`${shard1:0:16}\` |" \
  "| di_initializer.config.dart sha256 | \`${config0:0:16}\` | \`${config1:0:16}\` |" "" \
  "Spawns in the execution log after the edit:" "" '```' "$spawns" '```' "" \
  "- edited file's shard executed (cacheHit=False): ${shard_run:-NO}" \
  "- aggregate spawns that were not cache hits: ${agg_miss:-none}" \
  "- aggregate action spawns: ${agg:-none (action-cache hit)}" "" \
  "Package-local inputs of the aggregate action (aquery):" "" '```' "$inputs" '```'
ok=1
[[ "$shard0" == "$shard1" && "$config0" == "$config1" ]] || ok=0
[[ -n "$shard_run" ]] || ok=0
[[ -z "$agg_miss" ]] || ok=0
[[ -n "$spawns" ]] || ok=0
[[ $local_inputs_ok -eq 1 && -n "$inputs" ]] || ok=0
restore
bz build "$TARGET" > /dev/null 2>&1 || true
finish T-0028-AC2 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
