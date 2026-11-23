"""H-CFGDUP: count Dart actions that ran in more than one configuration.

Usage: python3 -I tool/checks/cfgdup.py exec_sim.json exec_host.json (run by T-0014-AC4_cfgdup_count.sh)
Each input is a Bazel --execution_log_json_file (a stream of JSON objects).
An action's identity is (mnemonic, target label, first output path with the
bazel-out/<config>/ segment removed). The same identity seen under two or more
configurations is a duplicate.
"""
import collections
import json
import re
import sys

MNEMONICS = ("DartKernel", "DartCodegen", "DartAnalyzerSummary", "DartKernelLink",
             "FlutterKernelCompile", "DartAnalyze", "DartFormat")


def spawns(path):
    dec = json.JSONDecoder()
    data = open(path).read()
    i = 0
    while True:
        while i < len(data) and data[i].isspace():
            i += 1
        if i >= len(data):
            return
        obj, i = dec.raw_decode(data, i)
        yield obj


def config_and_key(out_path):
    m = re.match(r"bazel-out/([^/]+)/(.*)", out_path)
    return (m.group(1), m.group(2)) if m else ("<src>", out_path)


rows = collections.defaultdict(set)   # (mnemonic, label, key) -> {config}
per_cfg = collections.Counter()       # (mnemonic, config) -> n
for path in sys.argv[1:]:
    for s in spawns(path):
        mn = s.get("mnemonic", "")
        if mn not in MNEMONICS:
            continue
        outs = s.get("listedOutputs") or [o.get("path") for o in s.get("actualOutputs", [])]
        if not outs:
            continue
        cfg, key = config_and_key(sorted(outs)[0])
        rows[(mn, s.get("targetLabel", ""), key)].add(cfg)
        per_cfg[(mn, cfg)] += 1

print("## Dart actions per mnemonic and configuration (both invocations)\n")
print("| Mnemonic | Configuration | Actions |")
print("|---|---|---|")
for (mn, cfg), n in sorted(per_cfg.items()):
    print(f"| {mn} | `{cfg}` | {n} |")

dups = {k: v for k, v in rows.items() if len(v) > 1}
by_mn = collections.Counter(k[0] for k in dups)
print("\n## Duplicated across configurations (same mnemonic, target and output path)\n")
print("| Mnemonic | Distinct actions | Duplicated in 2+ configs |")
print("|---|---|---|")
for mn in MNEMONICS:
    total = sum(1 for k in rows if k[0] == mn)
    if total:
        print(f"| {mn} | {total} | {by_mn.get(mn, 0)} |")
print("\n### First-party duplicates\n")
for (mn, label, key), cfgs in sorted(dups.items()):
    if label.startswith("//") or label.startswith("@@//"):
        print(f"- {mn} `{label}` → {', '.join(sorted(cfgs))}")

# Target-level view: the same target compiled in 2+ non-exec configurations,
# whatever the output name (kernel variants differ per configuration).
by_label = collections.defaultdict(set)
for (mn, label, key), cfgs in rows.items():
    for c in cfgs:
        if "exec" not in c:
            by_label[(mn, label)].add(c)
print("\n## By target label (non-exec configurations)\n")
print("| Mnemonic | Targets | Targets built in 2+ configs |")
print("|---|---|---|")
for mn in ("DartKernel", "DartCodegen"):
    labels = [k for k in by_label if k[0] == mn]
    if labels:
        print(f"| {mn} | {len(labels)} | {sum(1 for k in labels if len(by_label[k]) > 1)} |")
print(f"\nMACHINE codegen_dup={by_mn.get('DartCodegen', 0)} "
      f"codegen_total={sum(1 for k in rows if k[0] == 'DartCodegen')} "
      f"kernel_dup_exact={by_mn.get('DartKernel', 0)}")
