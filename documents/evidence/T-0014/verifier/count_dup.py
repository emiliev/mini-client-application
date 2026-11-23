#!/usr/bin/env python3
"""T-0014-AC4 (Verifier, independent of the Engineer's cfgdup.py).

Reads Bazel --execution_log_json_file outputs (a stream of SpawnExec JSON
objects) and counts Dart actions whose (mnemonic, target, output path with the
bazel-out/<config>/ prefix removed) appear under two or more configurations.

  python3 -I count_dup.py exec_sim.json exec_host.json
"""
import json
import re
import sys
from collections import defaultdict

DART = ("DartKernel", "DartCodegen", "DartAnalyzerSummary", "DartKernelLink",
        "DartAnalyze", "DartFormat")
CFG = re.compile(r"^bazel-out/([^/]+)/(.*)$")


def spawns(path):
    dec = json.JSONDecoder()
    buf = open(path, encoding="utf-8").read()
    i, n = 0, len(buf)
    while i < n:
        while i < n and buf[i] in " \r\n\t":
            i += 1
        if i >= n:
            break
        obj, i = dec.raw_decode(buf, i)
        yield obj


def main(paths):
    seen = defaultdict(set)          # key -> set of configs
    per_cfg = defaultdict(int)
    by_label = defaultdict(lambda: defaultdict(set))  # mnem -> label -> cfgs
    for p in paths:
        for s in spawns(p):
            m = s.get("mnemonic", "")
            if m not in DART:
                continue
            outs = s.get("listedOutputs") or [o.get("path") for o in s.get("actualOutputs", [])]
            cfgs, rels = set(), []
            for o in outs:
                mm = CFG.match(o or "")
                if mm:
                    cfgs.add(mm.group(1))
                    rels.append(mm.group(2))
            if not cfgs:
                continue
            cfg = sorted(cfgs)[0]
            per_cfg[(m, cfg)] += 1
            key = (m, s.get("targetLabel", ""), tuple(sorted(rels)))
            seen[key].add(cfg)
            if "-exec" not in cfg:
                by_label[m][s.get("targetLabel", "")].add(cfg)
    print("## Actions per mnemonic and configuration")
    for (m, c), k in sorted(per_cfg.items()):
        print(f"{m}\t{c}\t{k}")
    print("\n## Exact duplicates across configurations (mnemonic, target, output minus config)")
    for m in DART:
        keys = [k for k in seen if k[0] == m]
        dup = [k for k in keys if len(seen[k]) > 1]
        if keys:
            print(f"{m}\tdistinct={len(keys)}\tduplicated={len(dup)}")
            for k in sorted(dup):
                print(f"    {k[1]}  {sorted(seen[k])}")
    print("\n## Non-exec targets built in 2+ configurations (any output name)")
    for m in DART:
        labels = by_label.get(m, {})
        multi = [l for l, c in labels.items() if len(c) > 1]
        if labels:
            print(f"{m}\ttargets={len(labels)}\tin_2plus_configs={len(multi)}")


if __name__ == "__main__":
    main(sys.argv[1:])
