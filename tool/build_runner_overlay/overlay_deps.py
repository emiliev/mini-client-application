#!/usr/bin/env python3
"""What a build_runner overlay of one workspace package needs (P-059, T-0032).

  overlay_deps.py <repo root> <package dir> [--pure]

Prints one line per dependency:
  first<TAB><name><TAB><dir>   a workspace member the package depends on,
                               followed transitively (a path dependency);
  hosted<TAB><name>            a hosted dependency of the package itself
                               (not an SDK package, not a workspace member).
With --pure, members that depend on the Flutter SDK are left out (an overlay
resolved with `dart pub get` cannot hold them; Flutter-free inputs never
import them, R15).
"""
import os
import re
import sys

root, pkg = sys.argv[1], sys.argv[2]
pure = "--pure" in sys.argv[3:]


def read(p):
    return open(os.path.join(root, p, "pubspec.yaml")).read()


def name(text):
    return re.search(r"^name:\s*(\S+)", text, re.M).group(1)


def section(text):
    m = re.search(r"^dependencies:\n((?:[ \t]+.*\n?)*)", text, re.M)
    return m.group(1) if m else ""


def deps(text):
    return re.findall(r"^  ([a-z0-9_]+):", section(text), re.M)


def sdk(text):
    return set(re.findall(r"^  ([a-z0-9_]+):\n    sdk:", section(text), re.M))


workspace = open(os.path.join(root, "pubspec.yaml")).read()
members = re.search(r"^workspace:\n((?:\s+-\s*.+\n?)+)", workspace, re.M)
dirs = (
    [l.split("-", 1)[1].strip() for l in members.group(1).splitlines() if l.strip()]
    if members
    else []
)
by_name = {name(read(d)): d for d in dirs}

seen, todo = {}, [pkg]
while todo:
    for d in deps(read(todo.pop())):
        if d in by_name and d not in seen:
            seen[d] = by_name[d]
            todo.append(by_name[d])
for n, d in sorted(seen.items()):
    if pure and "flutter" in sdk(read(d)):
        continue
    print(f"first\t{n}\t{d}")
own = read(pkg)
for d in deps(own):
    if d not in by_name and d not in sdk(own):
        print(f"hosted\t{d}")
