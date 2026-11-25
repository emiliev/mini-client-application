#!/usr/bin/env python3
"""Adds `<name>: any` to a pubspec's `dependencies:` unless it is there already.

  add_dep.py <pubspec.yaml> <name>
"""
import re
import sys

path, dep = sys.argv[1], sys.argv[2]
text = open(path).read()
if not re.search(rf"^  {re.escape(dep)}:", text, re.M):
    text = text.replace("\ndependencies:\n", f"\ndependencies:\n  {dep}: any\n", 1)
open(path, "w").write(text)
