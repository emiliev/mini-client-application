#!/bin/bash
# fake runner scenarios: $1 = scenario
case $1 in
  retry) echo "Application failed to start on attempt: 1"; echo "flutter: 00:01 +1: All tests passed!"; exit 0 ;;
  real) echo "Application failed to start on attempt: 1"; echo "Could not build the application for the simulator."; exit 0 ;;
  *) echo ok; exit 0 ;;
esac
