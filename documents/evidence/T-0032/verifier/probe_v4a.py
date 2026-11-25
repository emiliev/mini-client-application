#!/usr/bin/env python3
"""Does `route.settings is Page` tell a flow page from a pushed route? Adds the
assertion to the preview step, runs BDD (a) unmutated and (b) with V4a, then
restores both files. Run from the repo root."""
import subprocess, sys
S = sys.argv[1]
STEP = "feature/characters/characters_list/test/feature/step/i_see_the_character_preview_for.dart"
TILE = "feature/characters/characters_list/lib/src/presentation/widget/character_tile.dart"
step0, tile0 = open(STEP).read(), open(TILE).read()
anchor = "  expect(route.settings.name, 'preview');\n"
assert step0.count(anchor) == 1
probe = anchor + "  expect(route.settings, isA<Page<Object?>>(), reason: 'a flow page, not a pushed route');\n"
TILE_ROUTE = open(S + "/probe_v4a_tile_route.dart.txt").read()

def run(tag):
    log = f"{S}/probe_{tag}.log"
    rc = subprocess.call(["tool/bazelw", "--output_base=/tmp/mc-ob-T-0032-verifier", "test", "--nocache_test_results",
                          "--output_groups=-dart_analyze,-dart_format",
                          "//feature/characters/characters_list:bdd_test"], stdout=open(log, "w"), stderr=subprocess.STDOUT)
    fails = [l.strip() for l in open(log, errors="replace") if l.startswith("  FAIL ")]
    print(tag, "rc", rc, fails, flush=True)

try:
    open(STEP, "w").write(step0.replace(anchor, probe))
    run("unmutated")
    open(TILE, "w").write(TILE_ROUTE)
    run("v4a")
finally:
    open(STEP, "w").write(step0)
    open(TILE, "w").write(tile0)
