#!/bin/bash
# T-0038 engineer mutation checks: each mutation must make a named test fail.
# Run from the worktree root. Restores every file with git checkout.
cd "$(git rev-parse --show-toplevel)" || exit 2
OB=/tmp/mc-ob-T-0038-engineer
P=utility/mc_fixtures_comics
H=$P/lib/src/handlers/comics_handlers.dart
U=$P/lib/src/data/universe.dart
run() { tool/bazelw --output_base=$OB test //utility/mc_fixtures_comics/... 2>&1 | grep -aE "FAILED|PASSED" ; }
mutate() {  # name file python-replace-old python-replace-new
  echo "=== $1"
  python3 -I - "$2" "$3" "$4" <<'EOF'
import sys
p,old,new=sys.argv[1:4]
s=open(p).read()
assert old in s, "pattern not found: "+old
open(p,'w').write(s.replace(old,new,1))
EOF
  run
  git checkout -- "$P"
}
#mutate "M1 title order as text (issue order)" $U "final bySeries = a.seriesTitle.compareTo(b.seriesTitle);
  if (bySeries != 0) {
    return bySeries;
  }
  final byIssue = a.issueNumber.compareTo(b.issueNumber);" "final bySeries = a.title.compareTo(b.title);
  if (bySeries != 0) {
    return bySeries;
  }
  final byIssue = a.issueNumber.compareTo(b.issueNumber);"
#mutate "M3 server_error set body differs" $H "'injected_failure',
      'Injected HTTP 500 for \${request.routeKey}'," "'server_error',
      'Injected HTTP 500 for \${request.routeKey}',"
mutate "M4 no id tie-break" $H "primary != 0 ? primary : a.id.compareTo(b.id);" "primary != 0 ? primary : (a.id - b.id).sign * 0;"
#mutate "M5 creator surnames partly unreachable" $U "c % creatorLastNames.length]" "(c ~/ creatorFirstNames.length) % creatorLastNames.length]"
#mutate "M6 banned word back" $P/lib/src/data/vocabulary.dart "'Crossing'" "'Gambit'"
echo "=== restored"; git status --short
