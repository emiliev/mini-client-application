#!/bin/bash
# T-0033 fix round: every fix has a test that fails without it. Each mutation
# reverts one fix in the working tree, runs the named test target, expects it
# to FAIL, and restores the file (also on error). Exit 1 when any mutation
# survives (its test still passed) or a restore fails.
#   MC_OB=/tmp/mc-ob-T-0033-engineer documents/evidence/T-0033/engineer/mutations.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO"
OB="${MC_OB:-/tmp/mc-ob-T-0033-engineer}"
rc=0
current=""
restore() { [ -n "$current" ] && [ -f "$current.mut-orig" ] && mv -f "$current.mut-orig" "$current"; current=""; }
trap restore EXIT

# mutate <name> <file> <python-old> <python-new> <target...>
mutate() {
  local name=$1 file=$2 old=$3 new=$4
  shift 4
  cp "$file" "$file.mut-orig"
  current=$file
  if ! /usr/bin/python3 -I - "$file" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
if old not in text:
    sys.exit("mutation text not found in " + path)
open(path, "w").write(text.replace(old, new, 1))
PY
  then
    echo "MUTATION $name: INVALID (text not found)"; rc=1; restore; return
  fi
  if tool/bazelw --output_base="$OB" test "$@" >/tmp/mc-mut.log 2>&1; then
    echo "MUTATION $name: SURVIVED (tests passed)  [$*]"; rc=1
  else
    echo "MUTATION $name: killed by $(grep -a -E '^//.*FAILED' /tmp/mc-mut.log | sed 's/ .*//' | tr '\n' ' ')"
  fi
  restore
}

mutate "scheme: normalise ignores the app's scheme" \
  app/wiring/app_core/lib/src/links/pending_links.dart \
  "uri == null || scheme.isForeign(uri)" "uri == null || LinkScheme.app.isForeign(uri)" \
  //app/wiring/app_core:router_ref_and_scheme_test //app/sandbox/universe_sandbox:universe_sandbox_links_test

mutate "scheme: sandbox router has no foreign-link guard" \
  app/sandbox/universe_sandbox/lib/src/universe_sandbox_router.dart \
  "scheme.isForeign(uri) || uri.path" "uri.path" \
  //app/sandbox/universe_sandbox:universe_sandbox_links_test

mutate "scheme: the sandbox installs its links with the default scheme" \
  app/sandbox/universe_sandbox/lib/src/universe_sandbox_app.dart \
  "PendingLinks.install(binding, scheme: sandboxLinkScheme)" "PendingLinks.install(binding)" \
  //app/sandbox/universe_sandbox:universe_sandbox_links_test

mutate "navigator: push becomes go" \
  app/wiring/universe_wiring/lib/src/navigators/characters_list_navigator_impl.dart \
  "_routerRef.router.push(" "_routerRef.router.go(" \
  //app/wiring/universe_wiring:routes_test

mutate "RouterRef.detach does nothing" \
  app/wiring/app_core/lib/src/router/router_ref.dart \
  "void detach() => _router = null;" "void detach() {}" \
  //app/wiring/app_core:router_ref_and_scheme_test

mutate "McApp.dispose does not detach" \
  app/wiring/app_core/lib/src/shell/mc_app.dart \
  "    widget.routerRef?.detach();
" "" \
  //app/wiring/app_core:router_ref_and_scheme_test

mutate "GoRouter registered as a caching singleton" \
  app/wiring/app_core/lib/src/router/router_ref.dart \
  "registerFactory<GoRouter>" "registerLazySingleton<GoRouter>" \
  //app/wiring/app_core:router_ref_and_scheme_test

mutate "MiniClientApp gives test initializers no router ref" \
  app/mini_client/lib/src/mini_client_app.dart \
  "widget.initializers?.call(_routerRef)" "widget.initializers?.call(RouterRef())" \
  //app/mini_client:app_test

mutate "navigator keeps the first router it saw (R2)" \
  app/wiring/universe_wiring/lib/src/navigators/characters_list_navigator_impl.dart \
  "  final RouterRef _routerRef;

  @override
  void openCharacter(CharacterId id) {
    unawaited(
      _routerRef.router.push(" \
  "  final RouterRef _routerRef;
  dynamic _first;

  @override
  void openCharacter(CharacterId id) {
    unawaited(
      (_first ??= _routerRef.router).push(" \
  //app/wiring/universe_wiring:routes_test

exit "$rc"
