# T-0014-AC1 launch on a private simulator
- simulator: mc-T-0014-engineer (03C9B8FA-A331-42B2-9893-C8A0EE33D993), iPhone 17 Pro, iOS 26.2 (deleted after the run)
- app: hello_ios.app from bazel-bin/spike/hello/hello_ios.ipa, bundle id com.emiliev.miniclient.spike.hello
- simctl launch: com.emiliev.miniclient.spike.hello: 70546
- launchctl entries for the app 8 s after launch: 1
- screenshot: ac1-launch-sim.png (original height 2622px)
