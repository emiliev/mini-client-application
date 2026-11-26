#!/bin/bash
cd "$(git rev-parse --show-toplevel)" || exit 2
H=utility/mc_fixtures_comics/lib/src/handlers/comics_handlers.dart
python3 -I - "$H" <<'EOF'
import sys
p=sys.argv[1]
s=open(p).read()
old="primary != 0 ? primary : a.id.compareTo(b.id);"
assert old in s
open(p,'w').write(s.replace(old,"primary != 0 ? primary : (a.id - b.id).sign * 0;",1))
EOF
echo "=== M4 no id tie-break"
tool/bazelw --output_base=/tmp/mc-ob-T-0038-engineer test //utility/mc_fixtures_comics/... 2>&1 | grep -aE "FAILED|PASSED|ERROR"
git checkout -- utility/mc_fixtures_comics
git status --short
