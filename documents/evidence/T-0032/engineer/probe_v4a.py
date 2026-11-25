#!/usr/bin/env python3
"""The Verifier's V4a probe (verifier/probe_v4a.py), re-run on the fix round.

V4a: the tile pushes the preview imperatively onto the flow's navigator
(`name: 'preview'`, `arguments: id`) and never touches the flow state. The
tile text is the Verifier's, updated for `CharacterPreviewPage(character:)`.

Runs :bdd_test three times, restoring every file afterwards:
  (a) the c3a5e82 step (before the fix) with V4a  -> expected: the two preview
      scenarios below pass (the Verifier's finding reproduced)
  (b) the fixed step, unmutated                   -> expected: PASS
  (c) the fixed step with V4a                     -> expected: both FAIL
Exit 1 if any expectation does not hold.

  python3 -I documents/evidence/T-0032/engineer/probe_v4a.py <output_base>
"""
import subprocess
import sys

OB = sys.argv[1]
PREVIEW_SCENARIOS = [
    "Tapping a character opens its preview inside the flow [T-0032-AC3]",
    "Going back from the preview keeps the list where I left it [T-0032-AC3]",
]
P = "feature/characters/characters_list"
STEP = f"{P}/test/feature/step/i_see_the_character_preview_for.dart"
TILE = f"{P}/lib/src/presentation/widget/character_tile.dart"
V4A_TILE = """import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/presentation/page/character_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';

class CharacterTile extends StatelessWidget {
  const CharacterTile({required this.character, super.key});

  final Character character;

  @override
  Widget build(BuildContext context) => McMediaCard(
    title: character.name,
    image: character.image,
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'preview', arguments: character.id),
        builder: (_) => CharacterPreviewPage(
          key: ValueKey(character.id),
          character: character,
        ),
      ),
    ),
  );
}
"""


def run(tag):
    log = f"/tmp/mc-T-0032-probe-{tag}.log"
    rc = subprocess.call(
        ["tool/bazelw", f"--output_base={OB}", "test", "--nocache_test_results",
         "--output_groups=-dart_analyze,-dart_format", f"//{P}:bdd_test"],
        stdout=open(log, "w"), stderr=subprocess.STDOUT)
    testlog = subprocess.run(
        ["tool/bazelw", f"--output_base={OB}", "info", "bazel-testlogs"],
        capture_output=True, text=True).stdout.strip() + f"/{P}/bdd_test/test.log"
    try:
        fails = [l.strip()[6:] for l in open(testlog, errors="replace") if l.startswith("  FAIL ")]
    except FileNotFoundError:
        fails = ["(no test log: the build failed)"]
    print(f"{tag}: rc {rc}, {len(fails)} failing: {fails}", flush=True)
    return rc, fails


step0, tile0 = open(STEP).read(), open(TILE).read()
old_step = subprocess.run(["git", "show", f"c3a5e82:{STEP}"], capture_output=True, text=True, check=True).stdout
ok = True
try:
    open(TILE, "w").write(V4A_TILE)
    open(STEP, "w").write(old_step)
    # The weakness the Verifier found: with the old step, the preview
    # scenarios cannot tell V4a from a flow page. (The fix round's new
    # double-tap scenario fails anyway: two pushes stack two routes.)
    rc, fails = run("a_old_step_v4a")
    ok &= not any(s in f for f in fails for s in PREVIEW_SCENARIOS)
    open(TILE, "w").write(tile0)
    open(STEP, "w").write(step0)
    rc, _ = run("b_fixed_step")
    ok &= rc == 0
    open(TILE, "w").write(V4A_TILE)
    rc, fails = run("c_fixed_step_v4a")
    ok &= rc != 0 and all(any(s in f for f in fails) for s in PREVIEW_SCENARIOS)
finally:
    open(STEP, "w").write(step0)
    open(TILE, "w").write(tile0)
print("PROBE", "OK" if ok else "UNEXPECTED")
sys.exit(0 if ok else 1)
