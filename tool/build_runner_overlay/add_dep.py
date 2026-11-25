#!/usr/bin/env python3
"""Adds `<name>: any` to a pubspec's `dependencies:` unless that block has it.

  add_dep.py <pubspec.yaml> <name>

Only the top-level `dependencies:` block counts: a package that appears only
under `dev_dependencies:` or `dependency_overrides:` is still added. The block
runs to the next top-level key; blank lines and comments inside it are
skipped (T-0032).
"""
import re
import sys


def block(lines, key):
    """Indices of the lines of top-level `key:`'s block (blank and comment
    lines excluded), and the index of the `key:` line itself (or None)."""
    start, out = None, []
    for i, line in enumerate(lines):
        if start is None:
            if re.match(rf"^{re.escape(key)}:\s*(#.*)?$", line):
                start = i
            continue
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line[0].isspace():
            break
        out.append(i)
    return start, out


def main():
    path, dep = sys.argv[1], sys.argv[2]
    lines = open(path).read().split("\n")
    start, body = block(lines, "dependencies")
    if start is None:
        sys.exit(f"add_dep: {path} has no top-level dependencies: block")
    names = {
        m.group(1)
        for i in body
        if (m := re.match(r"^  ([a-z0-9_]+):", lines[i]))
    }
    if dep not in names:
        lines.insert(start + 1, f"  {dep}: any")
        open(path, "w").write("\n".join(lines))


if __name__ == "__main__":
    main()
