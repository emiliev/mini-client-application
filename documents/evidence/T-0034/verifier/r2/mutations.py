"""T-0034 Verifier mutation driver. Each mutation: replace text in files,
run Bazel test targets uncached, record which targets fail, restore."""
import subprocess, sys, pathlib, re

REPO = pathlib.Path(sys.argv[1])
LOG = pathlib.Path(sys.argv[2])
ONLY = sys.argv[3].split(',') if len(sys.argv) > 3 else None
BZ = [str(REPO / 'tool/bazelw'), '--output_base=/tmp/mc-ob-T-0034-verifier']

FF = 'utility/mc_feature_flow/lib/src/'
MUTS = [
  ('M1', 'di listening again', [(FF + 'flow_context.dart', 'FlowScope.read(this).container<T>(', 'FlowScope.of(this).container<T>(')], ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test']),
  ('M3', 'provide: after flowInitializer',
   [(FF + 'feature_flow.dart',
     "          if (widget.provide case final provide?)\n            McDIInitializer((getIt, _) => provide(getIt)),\n          ?widget.flowInitializer,",
     "          ?widget.flowInitializer,\n          if (widget.provide case final provide?)\n            McDIInitializer((getIt, _) => provide(getIt)),")],
   ['//utility/mc_feature_flow:flow_kit_test']),
  ('D1', 'all mc delegates added, host overrides shadowed', [(FF + 'feature_flow.dart', "if (Localizations.of<Object>(context, delegate.type) == null) delegate,", "delegate,")], ['//utility/mc_feature_flow:flow_kit_test']),
  ('D2', 'no mc delegates added', [(FF + 'feature_flow.dart', "if (Localizations.of<Object>(context, delegate.type) == null) delegate,", "if (1 > 2) delegate,")], ['//utility/mc_feature_flow:flow_kit_test', '//feature/characters/characters_list:bdd_test']),
  ('T1', 'wrap only when delegates are non-empty (tree shape changes)',
   [(FF + 'feature_flow.dart', "    return Localizations.override(\n      context: context,", "    if (widget.localizationsDelegates.isEmpty) {\n      return _content(context);\n    }\n    return Localizations.override(\n      context: context,")], ['//utility/mc_feature_flow:flow_kit_test']),
  ('L1', 'flowLeading always null', [(FF + 'flow_context.dart', "    return BackButton(onPressed: () => unawaited(outer.maybePop()));", "    return null;")], ['//utility/mc_feature_flow:flow_kit_test']),
  ('L2', 'flowLeading ignores the inner navigator', [(FF + 'flow_context.dart', " || (inner?.canPop() ?? false)) {", " || (inner == null && false)) {")], ['//utility/mc_feature_flow:flow_kit_test']),
  ('L3', 'flowLeading pops the inner navigator', [(FF + 'flow_context.dart', "unawaited(outer.maybePop())", "unawaited(inner!.maybePop())")], ['//utility/mc_feature_flow:flow_kit_test']),
  ('L4', 'flowLeading ignores outer.canPop()', [(FF + 'flow_context.dart', "outer == null || !outer.canPop() ||", "outer == null ||")], ['//utility/mc_feature_flow:flow_kit_test']),
  ('H1', 'heightFor default hasSubtitle false', [('utility/mc_ds_cards/lib/src/mc_media_card.dart', "    bool hasSubtitle = true,", "    bool hasSubtitle = false,")], ['//utility/mc_ds_cards/...', '//utility/mc_ds_lists/...']),
  ('H2', 'no subtitle also drops a title line', [('utility/mc_ds_cards/lib/src/mc_media_card.dart', "        (hasSubtitle ? McSpacing.xxs + line(_subtitleStyle) : 0) +", "        (hasSubtitle ? McSpacing.xxs + line(_subtitleStyle) : -line(_titleStyle)) +")], ['//utility/mc_ds_cards/...', '//feature/characters/characters_list:golden_test', '//feature/characters/characters_list:bdd_test']),
  ('H3', 'exemplar back to the default (subtitle) height', [('feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart', "              hasSubtitle: false,\n", "")], ['//feature/characters/characters_list:golden_test']),
  ('B1', 'withTrailingSlash is the identity', [('utility/mc_config/lib/src/app_config.dart', "url.endsWith('/') ? url : '$url/'", "url")], ['//utility/mc_config/...', '//utility/mc_api_client/...', '//app/wiring/app_core/...']),
  ('B2', 'MockBackend.createDio does not normalise', [('utility/mc_mocked_backend/lib/src/backend.dart', "baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'", "baseUrl: baseUrl")], ['//utility/mc_mocked_backend/...']),
  ('M10', 'barrel without $PagedStateCopyWith', [('utility/mc_paging/lib/mc_paging.dart', 'show $PagedStateCopyWith, PagedState;', 'show PagedState;')], ['//utility/mc_paging:copywith_barrel_test']),
  ('M15', 'exemplar path v2', [('feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart', "@GET('v1/characters')", "@GET('v2/characters')")], ['//feature/characters/characters_list:bdd_test']),
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
