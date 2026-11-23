"""Execution-log ingestion and diff (T-0016 AC4).

Approach (see README): Bazel 9.2 only ships a converter inside its source tree, so this task ingests
`--execution_log_json_file` output. Note that Bazel 9.2 writes it as *concatenated pretty-printed
JSON objects*, not newline-delimited, so the reader is an incremental `raw_decode` loop. A compact
(zstd protobuf) log is supported through `--converter CMD`, whose stdout (JSON stream) feeds the
same reader. Nothing is sorted and nothing but a small per-spawn record is kept in memory.
"""
import argparse
import hashlib
import json
import subprocess
import sys

CHUNK = 1 << 20
_DEC = json.JSONDecoder()


def iter_json_objects(fh, chunk=CHUNK):
    """Yield objects from a text stream of concatenated JSON values, reading `chunk` chars at a time."""
    buf = ""
    eof = False
    while True:
        buf = buf.lstrip()
        if not buf:
            if eof:
                return
            data = fh.read(chunk)
            if not data:
                return
            buf = data
            continue
        try:
            obj, end = _DEC.raw_decode(buf)
        except json.JSONDecodeError:
            if eof:
                raise
            data = fh.read(chunk)
            if not data:
                eof = True
            buf += data
            continue
        yield obj
        buf = buf[end:]


def iter_spawns(path, converter=None):
    """Stream SpawnExec objects from a JSON log file, or from a converter command's stdout."""
    if converter:
        p = subprocess.Popen(converter + [path], stdout=subprocess.PIPE, text=True)
        try:
            yield from iter_json_objects(p.stdout)
        finally:
            p.stdout.close()
            p.wait()
        return
    with open(path, "r") as fh:
        yield from iter_json_objects(fh)


def spawn_key(sp):
    """Identity that pairs a spawn across two logs: mnemonic plus its sorted listed outputs."""
    return "|".join([sp.get("mnemonic", ""), sp.get("targetLabel", ""),
                     ",".join(sorted(sp.get("listedOutputs", [])))])


def inputs_digest(sp):
    """Digest of the spawn's inputs (path + content hash), order-independent. Tools included."""
    h = hashlib.sha256()
    for line in sorted("%s:%s" % (i.get("path", ""), i.get("digest", {}).get("hash", ""))
                       for i in sp.get("inputs", [])):
        h.update(line.encode())
        h.update(b"\n")
    return h.hexdigest()[:20]


def summarize(path, converter=None, collisions=None):
    """key -> record. Memory is O(#spawns) small records, independent of log size per spawn.

    Two spawns with the same key are never merged: the n-th repeat is stored as `key#n` (in log
    order) and the base key is appended to `collisions` when a list is given."""
    out = {}
    for sp in iter_spawns(path, converter):
        key = spawn_key(sp)
        if key in out:
            if collisions is not None:
                collisions.append(key)
            n = 1
            while "%s#%d" % (key, n) in out:
                n += 1
            key = "%s#%d" % (key, n)
        m = sp.get("metrics", {})
        out[key] = {
            "inputs": inputs_digest(sp),
            "label": sp.get("targetLabel", ""),
            "runner": sp.get("runner", ""),
            "cache_hit": bool(sp.get("cacheHit", False)),
            "wall": m.get("executionWallTime", ""),
            "n_inputs": len(sp.get("inputs", [])),
        }
    return out


def diff(a, b):
    """Pair spawns 1:1 by key and report those whose input digests changed."""
    paired = sorted(set(a) & set(b))
    changed = [k for k in paired if a[k]["inputs"] != b[k]["inputs"]]
    return {
        "paired": len(paired),
        "changed": changed,
        "changed_labels": sorted(b[k]["label"] for k in changed),
        "only_in_a": sorted(set(a) - set(b)),
        "only_in_b": sorted(set(b) - set(a)),
    }


def main(argv=None):
    ap = argparse.ArgumentParser(prog="execlog.py")
    ap.add_argument("a")
    ap.add_argument("b", nargs="?")
    ap.add_argument("--converter", nargs="+")
    ns = ap.parse_args(argv)
    ca, cb = [], []
    sa = summarize(ns.a, ns.converter, ca)
    if not ns.b:
        print(json.dumps({"spawns": len(sa), "key_collisions": ca}))
        return 0
    d = diff(sa, summarize(ns.b, ns.converter, cb))
    d["key_collisions"] = {"a": ca, "b": cb}
    print(json.dumps(d, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
