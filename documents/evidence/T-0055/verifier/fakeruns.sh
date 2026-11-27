#!/bin/bash
S=<scratch>
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a861080739e48eb98
P=$S/proj/app/mini_client
cd $S
run(){ n=$1; shift; mkdir -p ev/$n; "$W/tool/e2e_ios.sh" --task T-0055 --role verifier --project $P --evidence-dir $S/ev/$n --target integration_test/zz_good_test.dart "$@" > ev/$n/run.out 2>&1; echo "$n exit=$?"; grep -E '^==> (PASS|FAIL|RESULT)' ev/$n/run.out; grep '# e2e_ios.sh' ev/$n/e2e-zz_good_test.log; }
run retry --runner-cmd "$S/fake.sh retry {target}"
run real --runner-cmd "$S/fake.sh real {target}"
run sentinel --runner-cmd "$S/fake.sh ok 'BUILD FAILED Error (Xcode)' {target}"
run badid --bundle-id com.no.such.app --runner-cmd "$S/fake.sh ok {target}"
echo "--- build dir handling"
for v in plain keepflag appbin nobuild; do
  mkdir -p $P/build/ios/iphonesimulator/x
  case $v in
    plain) run k$v --runner-cmd "$S/fake.sh ok {target} #flutter drive" ;;
    keepflag) run k$v --keep-build --runner-cmd "$S/fake.sh ok {target} #flutter drive" ;;
    appbin) run k$v --runner-cmd "$S/fake.sh ok {target} #flutter drive --use-application-binary=x" ;;
    nobuild) run k$v --runner-cmd "$S/fake.sh ok {target} #flutter drive --no-build" ;;
  esac
  if [ -d $P/build/ios/iphonesimulator/x ]; then echo "$v: build dir KEPT"; else echo "$v: build dir REMOVED"; fi
done
xcrun simctl list devices | grep mc-
