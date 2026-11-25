#!/usr/bin/env python3
"""Verifier mutations for T-0032. Each mutation edits files, runs Bazel tests,
records killed / survived, and restores every file. Run from the repo root."""
import os, re, subprocess, sys, shutil, json

ROOT = os.getcwd()
OB = "--output_base=/tmp/mc-ob-T-0032-verifier"
P = "feature/characters/characters_list"
L = P + "/lib/src"
BDD = "//" + P + ":bdd_test"
GOLD = "//" + P + ":golden_test"
LOG_DIR = sys.argv[1]

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
        builder: (_) => CharacterPreviewPage(characterId: character.id),
      ),
    ),
  );
}
"""

# id, description, [(file, old, new)] (old=None: replace the whole file), targets
M = [
  ("V1", "AC1/AC5 limit 20 instead of 30",
   [(L+"/presentation/bloc/characters_list_bloc.dart", "const int charactersPageSize = 30;", "const int charactersPageSize = 20;")], [BDD]),
  ("V2a", "AC1 wrong sort: each page reversed by the mapper",
   [(L+"/domain/model/character_mapper.dart", "for (final dto in results) dto.toDomain()", "for (final dto in results.reversed) dto.toDomain()")], [BDD]),
  ("V2b", "AC1 wrong sort: the API asks for orderBy=-name",
   [(L+"/domain/api/characters_list_api.dart", "@Query('team') String? team,", "@Query('team') String? team,\n    @Query('orderBy') String orderBy = '-name',")], [BDD]),
  ("V2c", "AC1 wrong sort at the source: the fixture universe sorts by id (backend and expectation share it)",
   [("utility/mc_fixtures_characters/lib/src/data/universe.dart", "final byName = a.name.compareTo(b.name);", "final byName = a.id.compareTo(b.id);")],
   [BDD, "//utility/mc_fixtures_characters:all"]),
  ("V3", "AC3 openCharacter called twice",
   [(L+"/presentation/bloc/character_preview_bloc.dart", "_navigator.openCharacter(state.id);", "_navigator\n            ..openCharacter(state.id)\n            ..openCharacter(state.id);")], [BDD]),
  ("V4a", "AC3 preview pushed as a route on the flow's navigator (flow state untouched)",
   [(L+"/presentation/widget/character_tile.dart", None, TILE_ROUTE % "")], [BDD, GOLD]),
  ("V4b", "AC3 preview pushed as a route on the root navigator",
   [(L+"/presentation/widget/character_tile.dart", None, TILE_ROUTE % ", rootNavigator: true")], [BDD]),
  ("V5a", "AC5 no de-dup of page 2: controller in-flight guard removed",
   [("utility/mc_paging/lib/src/paging_controller.dart", "        _state.hasReachedEnd ||\n        _inFlight ||", "        _state.hasReachedEnd ||")], [BDD]),
  ("V5b", "AC5 no de-dup of page 2: grid latch and isLoadingMore check removed",
   [("utility/mc_ds_lists/lib/src/paged_body.dart", "        !s.isLoadingMore &&\n", ""),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "    } else if (!_requested) {", "    } else {")], [BDD]),
  ("V5c", "AC5 no de-dup of page 2: both layers removed (V5a + V5b)",
   [("utility/mc_paging/lib/src/paging_controller.dart", "        _state.hasReachedEnd ||\n        _inFlight ||", "        _state.hasReachedEnd ||"),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "        !s.isLoadingMore &&\n", ""),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "    } else if (!_requested) {", "    } else {")], [BDD]),
  ("V5d", "AC5 no de-dup in the feature: the bloc fires loadMore without awaiting, twice",
   [(L+"/presentation/bloc/characters_list_bloc.dart", "      case _LoadMore():\n        await _paging.loadMore();", "      case _LoadMore():\n        unawaited(_paging.loadMore());\n        await Future<void>.delayed(Duration.zero);\n        await _paging.loadMore();")], [BDD]),
  ("V6a", "AC4 German title key missing (falls back to English)",
   [(L+"/l10n/characters_list_de.arb", '  "charactersListTitle": "Figuren",\n', "")], [BDD, "//tool/l10n_check:workspace_gate_test"]),
  ("V6b", "AC4 German preview-button key missing (falls back to English)",
   [(L+"/l10n/characters_list_de.arb", ',\n  "charactersListPreviewSeeFullProfile": "Vollständiges Profil ansehen"', "")], [BDD, "//tool/l10n_check:workspace_gate_test"]),
  ("V6c", "AC4 German preview button holds the English text",
   [(L+"/l10n/characters_list_de.arb", '"Vollständiges Profil ansehen"', '"See full profile"')], [BDD]),
  ("V7a", "AC5 end guard removed in the controller",
   [("utility/mc_paging/lib/src/paging_controller.dart", "        _state.hasReachedEnd ||\n", "")], [BDD]),
  ("V7b", "AC5 end guard removed in the grid",
   [("utility/mc_ds_lists/lib/src/paged_body.dart", "        !s.hasReachedEnd &&\n", "")], [BDD]),
  ("V7c", "AC5 end guard removed in both layers",
   [("utility/mc_paging/lib/src/paging_controller.dart", "        _state.hasReachedEnd ||\n", ""),
    ("utility/mc_ds_lists/lib/src/paged_body.dart", "        !s.hasReachedEnd &&\n", "")], [BDD]),
  ("V8", "AC3 back rebuilds the list page (scroll lost)",
   [(L+"/flow/characters_list_flow.dart", "const McFlowPage(name: 'list', child: CharactersListPage()),", "McFlowPage(name: 'list', child: CharactersListPage(key: UniqueKey())),")], [BDD]),
  ("V9", "AC2 Retry on a failed second page does nothing",
   [(L+"/presentation/bloc/characters_list_bloc.dart", "      case _Retry():\n        await _paging.retry();", "      case _Retry():\n        if (state is! _Success) {\n          await _paging.retry();\n        }")], [BDD]),
  ("V10", "AC1 image from the wrong thumbnail",
   [(L+"/domain/model/character_mapper.dart", "path: thumbnail.path,", "path: 'mock-asset://characters/000',")], [BDD]),
]

only = set(sys.argv[2:])
results = []
for mid, what, edits, targets in M:
    if only and mid not in only:
        continue
    files = sorted({f for f, _, _ in edits})
    backup = {f: open(f, encoding="utf-8").read() for f in files}
    ok = True
    for f, old, new in edits:
        s = open(f, encoding="utf-8").read()
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
               "--output_groups=-dart_analyze,-dart_format", "--keep_going", "--test_output=errors"] + targets
        with open(log, "w") as out:
            rc = subprocess.call(cmd, stdout=out, stderr=subprocess.STDOUT)
        text = open(log, errors="replace").read()
        if rc == 0:
            verdict = "SURVIVED"
        elif "FAILED TO BUILD" in text or "Build did NOT complete" in text and "FAILED in" not in text:
            verdict = "DID NOT COMPILE"
        else:
            failed = sorted(set(re.findall(r"^\s+FAIL\s*\]?\s*(.*)$", text, re.M)))
            n = len(re.findall(r"^//\S+\s+FAILED in", text, re.M))
            verdict = f"KILLED ({n} target(s) failed)"
        line = f"{mid} {verdict}: {what}"
        print(line, flush=True)
        results.append(line)
    for f in files:
        open(f, "w", encoding="utf-8").write(backup[f])

subprocess.call(["git", "status", "--short"])
