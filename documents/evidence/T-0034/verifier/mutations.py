"""T-0034 Verifier mutation driver. Each mutation: replace text in files,
run Bazel test targets uncached, record which targets fail, restore."""
import subprocess, sys, pathlib, re

REPO = pathlib.Path(sys.argv[1])
LOG = pathlib.Path(sys.argv[2])
ONLY = sys.argv[3].split(',') if len(sys.argv) > 3 else None
BZ = [str(REPO / 'tool/bazelw'), '--output_base=/tmp/mc-ob-T-0034-verifier']

FF = 'utility/mc_feature_flow/lib/src/'
MUTS = [
  ('M1', 'di listening again (FlowScope.of in McFlowContext.di)',
   [(FF + 'flow_context.dart', 'FlowScope.read(this).container<T>(', 'FlowScope.of(this).container<T>(')],
   ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test']),
  ('M2', 'debugResolveAll listening again',
   [(FF + 'flow_context.dart', 'FlowScope.read(this).container.debugResolveAll()', 'FlowScope.of(this).container.debugResolveAll()')],
   ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:flow_scope_test']),
  ('M3', 'provide: registered after flowInitializer',
   [(FF + 'feature_flow.dart',
     "          if (widget.provide case final provide?)\n            McDIInitializer((getIt, _) => provide(getIt)),\n          ?widget.flowInitializer,",
     "          ?widget.flowInitializer,\n          if (widget.provide case final provide?)\n            McDIInitializer((getIt, _) => provide(getIt)),")],
   ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test', '//feature/characters/characters_list:flow_scope_test']),
  ('M3P', 'provide: after flowInitializer, probe P1',
   [(FF + 'feature_flow.dart',
     "          if (widget.provide case final provide?)\n            McDIInitializer((getIt, _) => provide(getIt)),\n          ?widget.flowInitializer,",
     "          ?widget.flowInitializer,\n          if (widget.provide case final provide?)\n            McDIInitializer((getIt, _) => provide(getIt)),")],
   ['//utility/mc_feature_flow:verifier_probe_test']),
  ('M5', 'provide: ignored',
   [(FF + 'feature_flow.dart', 'McDIInitializer((getIt, _) => provide(getIt)),', 'McDIInitializer((getIt, _) {}),')],
   ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test']),
  ('M6', 'core + Flutter delegates not appended',
   [(FF + 'feature_flow.dart', 'delegates: [...delegates, ...mcLocalizationsDelegates],', 'delegates: [...delegates],')],
   ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test']),
  ('M7', 'feature delegates dropped',
   [(FF + 'feature_flow.dart', 'delegates: [...delegates, ...mcLocalizationsDelegates],', 'delegates: [...mcLocalizationsDelegates],')],
   ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test']),
  ('M8', 'flowStateOf without the type check',
   [('utility/mc_feature_flow/lib/testing.dart', 'if (state is! S) {', 'if (state is! S && 1 > 2) {'),
    ('utility/mc_feature_flow/lib/testing.dart', '  return state;\n}', '  return state as S;\n}')],
   ['//utility/mc_feature_flow:flow_kit_test']),
  ('M10', 'mc_paging barrel without $PagedStateCopyWith',
   [('utility/mc_paging/lib/mc_paging.dart', 'show $PagedStateCopyWith, PagedState;', 'show PagedState;')],
   ['//utility/mc_paging:copywith_barrel_test', '//feature/characters/characters_list:bdd_test']),
  ('M11', 'AppConfig.fromJson does not normalise',
   [('utility/mc_config/lib/src/app_config.dart', "apiBaseUrl: withTrailingSlash(json['apiBaseUrl'] as String),", "apiBaseUrl: json['apiBaseUrl'] as String,")],
   ['//utility/mc_config:app_config_test', '//app/wiring/app_core:boot_test', '//app/mini_client/...']),
  ('M12', 'createApiDio without the assert',
   [('utility/mc_api_client/lib/src/api_dio.dart', "    baseUrl.endsWith('/'),\n    'The API", "    true,\n    'The API")],
   ['//utility/mc_api_client:api_client_test']),
  ('M13', 'withTrailingSlash adds a slash always (double slash)',
   [('utility/mc_config/lib/src/app_config.dart', "url.endsWith('/') ? url : '$url/'", "'$url/'")],
   ['//utility/mc_config:app_config_test']),
  ('M14', 'exemplar path back to a leading slash',
   [('feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart', "@GET('v1/characters')", "@GET('/v1/characters')")],
   ['//feature/characters/characters_list:bdd_test', '//feature/characters/characters_list:contract_test']),
  ('M15', 'exemplar path wrong (v2)',
   [('feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart', "@GET('v1/characters')", "@GET('v2/characters')")],
   ['//feature/characters/characters_list:bdd_test']),
]

def run(targets):
  if not targets:
    return 0, ''
  import os
  extra = ['--test_output=all'] if os.environ.get('DETAIL') else []
  p = subprocess.run(BZ + ['test', '--nocache_test_results', '--keep_going'] + extra + targets,
                     cwd=REPO, capture_output=True, text=True)
  out = (p.stdout + p.stderr).replace('\r', '\n')
  if os.environ.get('DETAIL'):
    pathlib.Path(os.environ['DETAIL']).write_text(out)
  lines = [l for l in out.splitlines() if re.search(r'(PASSED|FAILED|NO STATUS|FAILED TO BUILD|Executed|ERROR:)', l)]
  return p.returncode, '\n'.join(lines[-30:])

with LOG.open('a') as log:
  for mid, desc, edits, targets in MUTS:
    if ONLY and mid not in ONLY:
      continue
    saved = {}
    ok = True
    for f, old, new in edits:
      path = REPO / f
      text = saved.get(f) or path.read_text()
      saved.setdefault(f, text)
      cur = path.read_text()
      if cur.count(old) != 1:
        log.write(f'## {mid} SKIP: pattern count {cur.count(old)} in {f}\n'); ok = False; break
      path.write_text(cur.replace(old, new))
    if ok:
      rc, summary = run(targets)
      log.write(f'## {mid}: {desc}\nexit={rc}\n{summary}\n\n')
      log.flush()
    for f, text in saved.items():
      (REPO / f).write_text(text)
