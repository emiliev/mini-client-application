#!/bin/bash
# T-0041 Verifier negative controls and cutoff probes (run after mutations,
# on a clean tree). Every edit is restored with `git checkout`.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-aedf1b73f30091004
S=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0041-verifier
cd "$W"
OB=/tmp/mc-ob-T-0041-verifier
export MC_BAZEL_STARTUP=--output_base=$OB
LOG=$S/controls.log
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base=$OB "$@"; }
[[ -z "$(git status --porcelain)" ]] || { say "REFUSING: tree not clean"; exit 2; }
PKG=feature/comics/comics_details
TARGET=//$PKG:comics_details

# ---- 1. arch check: a non-Flow member on PublishingRouteTargets ----------
RT=app/wiring/publishing_wiring/lib/src/routes/route_targets.dart
/usr/bin/python3 -I - "$RT" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = "  CreatorDetailsPlaceholderFlow creatorDetails(int id);\n"
assert old in s
open(p, "w").write(s.replace(old, old + "\n  String label();\n"))
EOF
out="$(bz run //tool/mc_arch_check:bin 2>&1 | tr '\r' '\n' | grep -a -v '^INFO\|^Loading\|^Analyzing\|^Computing' | tail -6)"; rc=$?
say "## arch check negative control (PublishingRouteTargets.label returns String)"
say "$out"
git checkout -- "$RT"
out="$(bz run //tool/mc_arch_check:bin 2>&1 | tr '\r' '\n' | grep -a 'mc_arch_check' | tail -2)"
say "## arch check after restore: $out"

# ---- 2. fixtures closure: mc_fixtures_characters depends on media again ---
FB=utility/mc_fixtures_characters/BUILD.bazel
/usr/bin/python3 -I - "$FB" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = '        "//utility/mc_media",\n        "//utility/mc_mocked_backend",\n    ],\n)'
assert old in s
open(p, "w").write(s.replace(old, '        "//utility/mc_fixtures_media",\n' + old, 1))
EOF
tool/checks/T-0041-AC1_fixtures_closure.sh > "$S/neg_fixtures_closure.md" 2>&1; rc=$?
say "## T-0041-AC1 closure with mc_fixtures_media planted in mc_fixtures_characters: exit $rc"
grep -a -E '^##|Flutter markers|PASS|FAIL' "$S/neg_fixtures_closure.md" | head -12 | tee -a "$LOG"
git checkout -- "$FB"
tool/checks/T-0041-AC1_fixtures_closure.sh > "$S/fixtures_closure.md" 2>&1; rc=$?
say "## T-0041-AC1 closure after restore: exit $rc"

# ---- 3. T-0031-AC6 fixtures check: comics_details lib depends on a fixture -
CB=$PKG/BUILD.bazel
grep -n '"//utility/mc_formatters",' "$CB" | head -3 | tee -a "$LOG"
/usr/bin/python3 -I - "$CB" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = '"//utility/mc_formatters",\n'
assert old in s
open(p, "w").write(s.replace(old, old + '        "//utility/mc_fixtures_comics",\n', 1))
EOF
MC_OUTPUT_BASE=$OB tool/checks/T-0031-AC6_closure.sh > "$S/neg_t0031.md" 2>&1; rc=$?
say "## T-0031-AC6 fixtures check with mc_fixtures_comics planted in comics_details' first dep list: exit $rc"
grep -a -i -E 'fixtures|FAIL|PASS' "$S/neg_t0031.md" | tail -8 | tee -a "$LOG"
git checkout -- "$CB"

# ---- 4. cutoff: outline edits DO re-run what they should ---------------------
spawns() { /usr/bin/python3 -I - "$1" <<'EOF'
import json, sys
text = open(sys.argv[1]).read()
dec, i = json.JSONDecoder(), 0
while i < len(text):
    while i < len(text) and text[i].isspace(): i += 1
    if i >= len(text): break
    s, i = dec.raw_decode(text, i)
    print(f"{s.get('mnemonic')}\t{s.get('targetLabel')}\tcacheHit={s.get('cacheHit', False)}")
EOF
}
bz build --remote_download_all $TARGET > /dev/null 2>&1 || say "baseline build failed"
BIN="$(bz info bazel-bin 2>/dev/null)/$PKG/lib/src"
cfg0=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -c1-16)
api0=$(shasum -a 256 "$BIN/domain/api/comics_details_api.g.dart" | cut -c1-16)

API=$PKG/lib/src/domain/api/comics_details_api.dart
/usr/bin/python3 -I - "$API" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = "  Future<FavouriteDto> deleteFavourite(@Path('id') int id);\n"
assert old in s
open(p, "w").write(s.replace(old, old + "\n  @GET('v1/comics/{id}/probe')\n  Future<ComicDto> probe(@Path('id') int id);\n"))
EOF
fvm dart format "$API" > /dev/null
bz build --remote_download_all --execution_log_json_file="$S/cut_api.json" $TARGET > "$S/cut_api.log" 2>&1 || say "API edit build failed"
api1=$(shasum -a 256 "$BIN/domain/api/comics_details_api.g.dart" | cut -c1-16)
cfg1=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -c1-16)
say "## cutoff probe A: a new method on ComicsDetailsApi (API signature edit)"
say "api.g.dart $api0 -> $api1; config.dart $cfg0 -> $cfg1"
spawns "$S/cut_api.json" | grep -a -E 'retrofit|_api_g|Aggregate|_api_inj' | tee -a "$LOG"
git checkout -- "$API"

DETB=$PKG/lib/src/presentation/bloc/comic_details_bloc.dart
/usr/bin/python3 -I - "$DETB" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = "@injectable\nfinal class ComicDetailsBloc"
assert old in s
open(p, "w").write(s.replace(old, "@lazySingleton\nfinal class ComicDetailsBloc"))
EOF
bz build --remote_download_all --execution_log_json_file="$S/cut_bloc.json" $TARGET > "$S/cut_bloc.log" 2>&1 || say "bloc annotation build failed"
cfg2=$(shasum -a 256 "$BIN/di/di_initializer.config.dart" | cut -c1-16)
api2=$(shasum -a 256 "$BIN/domain/api/comics_details_api.g.dart" | cut -c1-16)
say "## cutoff probe B: ComicDetailsBloc @injectable -> @lazySingleton (registration outline edit)"
say "config.dart $cfg0 -> $cfg2; api.g.dart $api0 -> $api2"
spawns "$S/cut_bloc.json" | grep -a -E 'Aggregate|comic_details_bloc_inj|retrofit' | tee -a "$LOG"
git checkout -- "$DETB"
bz build $TARGET > /dev/null 2>&1

# ---- 5. byte identity, re-run with reports --------------------------------
tool/checks/T-0041-AC7_matches_build_runner.sh --role verifier --out "$S/byte_identity_comics_details.md" > /dev/null 2>&1; say "## T-0041-AC7 byte identity: exit $?"
grep -a -E 'expected files EQUAL|not EQUAL|not on the list' "$S/byte_identity_comics_details.md" | tee -a "$LOG"
tool/checks/T-0032-AC6_matches_build_runner.sh --role verifier --out "$S/byte_identity_characters_list.md" > /dev/null 2>&1; say "## T-0032-AC6 byte identity (characters_list): exit $?"
grep -a -E 'EQUAL|not EQUAL|not on the list' "$S/byte_identity_characters_list.md" | grep -a -v '^EQUAL' | tee -a "$LOG"
tool/checks/T-0041-AC7_cutoff.sh --role verifier --out "$S/cutoff_body.md" > /dev/null 2>&1; say "## T-0041-AC7 cutoff (body edit): exit $?"
grep -a -E '^\| ' "$S/cutoff_body.md" | tee -a "$LOG"

[[ -z "$(git status --porcelain)" ]] && say "tree clean" || { say "TREE NOT CLEAN"; git status --short | tee -a "$LOG"; }
