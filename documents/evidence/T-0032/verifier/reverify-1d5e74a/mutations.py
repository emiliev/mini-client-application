#!/usr/bin/env python3
"""Verifier re-verification mutations for T-0032 at 1d5e74a. Each mutation
edits (or creates) files, runs Bazel tests, records killed / survived, and
restores every file (created files are deleted). Run from the repo root:
  mutate2.py <log dir> [ids...]"""
import os, re, subprocess, sys

OB = "--output_base=/tmp/mc-ob-T-0032-verifier"
P = "feature/characters/characters_list"
L = P + "/lib/src"
T = P + "/test/feature"
BDD = "//" + P + ":bdd_test"
GOLD = "//" + P + ":golden_test"
LOG_DIR = sys.argv[1]
STEP = T + "/step/i_see_the_character_preview_for.dart"

TILE_ROUTE = """import 'package:characters_list/src/domain/model/character.dart';
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
    onTap: () => Navigator.of(context%s).push(
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

PAGE_CHECK = """  expect(
    route.settings,
    isA<Page<Object?>>(),
    reason: 'a flow page, not a pushed route',
  );
"""

# A tap on a second tile while the first preview is mid-slide (not the same
# frame): the real-user window the engineer says the modal barrier closes.
SLIDE_FEATURE = """Feature: Probe slide-in

  Background:
    Given the backend serves {'characters.default'}

  Scenario: Probe a tap during the slide-in
    When I open the characters list
    And I tap {'Amber Alchemist'} then {'Amber Bard'} during the slide-in
    Then I see the character preview for {'Amber Alchemist'}
    When I tap {'See full profile'}
    Then the app was asked to open character {'Amber Alchemist'}
"""
SLIDE_STEP = """import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I tap {'Amber Alchemist'} then {'Amber Bard'} during the slide-in
Future<void> iTapThenDuringTheSlidein(
  WidgetTester tester,
  String first,
  String second,
) async {
  final at = tester.getCenter(find.text(second).hitTestable());
  await tester.tap(find.text(first).hitTestable());
  final title = find.byKey(characterPreviewTitleKey, skipOffstage: false);
  for (var i = 0; i < 30 && title.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(title, findsOneWidget, reason: 'the preview route exists');
  await tester.pump(const Duration(milliseconds: 60));
  final route = ModalRoute.of(tester.element(title))!;
  final value = route.animation!.value;
  expect(value, greaterThan(0), reason: 'the slide-in started');
  expect(value, lessThan(1), reason: 'still sliding in');
  // ignore: avoid_print
  print('PROBE slide-in at ${value.toStringAsFixed(2)}; tapping $second at $at');
  await tester.tapAt(at);
  await mcSettle(tester);
}
"""
SLIDE_FILES = [(T + "/probe_slide.feature", None, SLIDE_FEATURE),
               (T + "/step/i_tap_then_during_the_slidein.dart", None, SLIDE_STEP)]
NO_GUARD = (L + "/presentation/bloc/characters_list_bloc.dart",
            "if (_flow.state.preview == null) {", "if (_flow.state.preview == null || identical(1, 1)) {")

M = [
  ("R1", "AC3 V4a adapted: preview pushed onto the flow's navigator, flow state untouched",
   [(L+"/presentation/widget/character_tile.dart", None, TILE_ROUTE % "")], [BDD, GOLD]),
  ("R2", "AC3 V4a with the step's Page check removed: the flow-state read alone must kill it",
   [(L+"/presentation/widget/character_tile.dart", None, TILE_ROUTE % ""), (STEP, PAGE_CHECK, "")], [BDD]),
  ("R3", "AC3 V4b: preview pushed onto the root navigator",
   [(L+"/presentation/widget/character_tile.dart", None, TILE_ROUTE % ", rootNavigator: true")], [BDD]),
  ("R5", "AC3 double-tap guard removed (same-frame second tap)",
   [NO_GUARD], [BDD]),
  ("R6", "AC3 preview page no longer keyed by the character id",
   [(L+"/flow/characters_list_flow.dart", "              key: ValueKey(character.id),\n", "")], [BDD]),
  ("P1", "probe: a second tap mid slide-in, guard in place",
   SLIDE_FILES, [BDD]),
  ("P2", "probe: a second tap mid slide-in, guard removed",
   SLIDE_FILES + [NO_GUARD], [BDD]),
  ("V1", "limit 20 instead of 30",
   [(L+"/presentation/bloc/characters_list_bloc.dart", "const int charactersPageSize = 30;", "const int charactersPageSize = 20;")], [BDD]),
  ("V2b", "wrong sort: the API asks for orderBy=-name",
   [(L+"/domain/api/characters_list_api.dart", "@Query('team') String? team,", "@Query('team') String? team,\n    @Query('orderBy') String orderBy = '-name',")], [BDD]),
  ("V3", "openCharacter called twice",
   [(L+"/presentation/bloc/character_preview_bloc.dart", "_navigator.openCharacter(state.id);", "_navigator\n            ..openCharacter(state.id)\n            ..openCharacter(state.id);")], [BDD]),
  ("V5c", "no de-dup of page 2 (both layers)",
   [("utility/mc_paging/lib/src/paging_controller.dart", "        _state.hasReachedEnd ||\n        _inFlight ||", "        _state.hasReachedEnd ||"),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "        !s.isLoadingMore &&\n", ""),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "    } else if (!_requested) {", "    } else {")], [BDD]),
  ("V6b", "German preview-button key missing",
   [(L+"/l10n/characters_list_de.arb", ',\n  "charactersListPreviewSeeFullProfile": "Vollständiges Profil ansehen"', "")], [BDD, "//tool/l10n_check:workspace_gate_test"]),
  ("V7c", "end guard removed (both layers)",
   [("utility/mc_paging/lib/src/paging_controller.dart", "        _state.hasReachedEnd ||\n", ""),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "        !s.hasReachedEnd &&\n", "")], [BDD]),
  ("V8", "list page rebuilt on back (scroll lost)",
   [(L+"/flow/characters_list_flow.dart", "const McFlowPage(name: 'list', child: CharactersListPage()),", "McFlowPage(name: 'list', child: CharactersListPage(key: UniqueKey())),")], [BDD]),
  ("V10", "every character's art is 000",
   [(L+"/domain/model/character_mapper.dart", "path: thumbnail.path,", "path: 'mock-asset://characters/000',")], [BDD]),
  ("H1", "recover() leaves the harness's fail mirrors (old behaviour)",
   [("utility/mc_test_utils/lib/src/backend_harness.dart", "    _failRules.clear();\n", "")], ["//utility/mc_test_utils:harness_test"]),
  ("H2", "recover() leaves engine rules live",
   [("utility/mc_test_utils/lib/src/backend_harness.dart", "      rule.live = false;\n", "")], ["//utility/mc_test_utils:harness_test", BDD]),
  ("H3", "recover() resets the whole engine (old backend.reset())",
   [("utility/mc_test_utils/lib/src/backend_harness.dart", "    backend.useScenario(null);\n", "    backend.reset();\n")], ["//utility/mc_test_utils:harness_test"]),
  ("K7", "flow no longer keyed by initialTeamId",
   [(L+"/flow/characters_list_flow.dart", "      key: ValueKey(initialTeamId),\n", "")], ["//" + P + ":flow_scope_test"]),
  ("K12", "synthetic names padded to 2 digits again",
   [("utility/mc_fixtures_characters/lib/src/data/universe.dart", "padLeft(width, '0')", "padLeft(2, '0')")], ["//utility/mc_fixtures_characters:fixture_sets_test"]),

]

only = set(sys.argv[2:])
for mid, what, edits, targets in M:
    if only and mid not in only:
        continue
    files = sorted({f for f, _, _ in edits})
    backup = {f: (open(f, encoding="utf-8").read() if os.path.exists(f) else None) for f in files}
    ok = True
    for f, old, new in edits:
        s = open(f, encoding="utf-8").read() if os.path.exists(f) else ""
        if old is None:
            s = new
        elif s.count(old) != 1:
            ok = False
            print(f"{mid} NOT APPLIED: {old!r} in {f}", flush=True)
            break
        else:
            s = s.replace(old, new)
        open(f, "w", encoding="utf-8").write(s)
    if ok:
        log = os.path.join(LOG_DIR, f"{mid}.log")
        cmd = ["tool/bazelw", OB, "test", "--nocache_test_results",
               "--output_groups=-dart_analyze,-dart_format", "--keep_going", "--test_output=all"] + targets
        with open(log, "w") as out:
            rc = subprocess.call(cmd, stdout=out, stderr=subprocess.STDOUT)
        text = open(log, errors="replace").read()
        fails = sorted(set(m.strip() for m in re.findall(r"^\s+FAIL\s+(.*)$", text, re.M)))
        if rc == 0:
            verdict = "SURVIVED"
        elif not re.search(r"^//\S+\s+FAILED in", text, re.M):
            verdict = "DID NOT COMPILE / BUILD FAILED"
        else:
            verdict = f"KILLED: {'; '.join(fails) or 'target failed'}"
        probe = re.findall(r"PROBE .*", text)
        print(f"{mid} {verdict} :: {what}" + (f" [{probe[0]}]" if probe else ""), flush=True)
    for f in files:
        if backup[f] is None:
            os.remove(f)
        else:
            open(f, "w", encoding="utf-8").write(backup[f])
