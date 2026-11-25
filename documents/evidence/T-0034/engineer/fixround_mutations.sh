#!/bin/bash
# T-0034 fix-round mutation probes: each mutation must make the named tests fail.
cd /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a9e3fa7219730d215 || exit 1
OB=/tmp/mc-ob-T-0034-engineer
run() {  # run <label> <file> <python-edit> <targets...>
  local label="$1" file="$2" edit="$3"; shift 3
  python3 -c "
import sys
p='$file'
s=open(p).read()
a,b=$edit
assert a in s, a
open(p,'w').write(s.replace(a,b,1))
" || { echo "MUTATION $label: edit failed"; return; }
  echo "=== $label"
  tool/bazelw --output_base=$OB test "$@" --test_output=errors 2>&1 | grep -E "^\s+FAIL|FAILED|PASSED|ERROR:.*(Dart|error)" | head -12
  git checkout -- "$file"
}
FF=utility/mc_feature_flow/lib/src/feature_flow.dart
run "M1 flow re-adds every core/Flutter delegate" $FF "('if (Localizations.of<Object>(context, delegate.type) == null) delegate,','delegate,')" //utility/mc_feature_flow:flow_kit_test
run "M2 provide after flowInitializer" $FF "('''          if (widget.provide case final provide?)
            McDIInitializer((getIt, _) => provide(getIt)),
          ?widget.flowInitializer,''','''          ?widget.flowInitializer,
          if (widget.provide case final provide?)
            McDIInitializer((getIt, _) => provide(getIt)),''')" //utility/mc_feature_flow:flow_kit_test
run "M3 unwrapped when there are no delegates" $FF "('''    return Localizations.override(
      context: context,
      delegates: [...widget.localizationsDelegates, ...missing],''','''    if (widget.localizationsDelegates.isEmpty) return _content(context);
    return Localizations.override(
      context: context,
      delegates: [...widget.localizationsDelegates, ...missing],''')" //utility/mc_feature_flow:flow_kit_test
run "M4 no flow leading" utility/mc_feature_flow/lib/src/flow_context.dart "('    return BackButton(onPressed: () => unawaited(outer.maybePop()));','    return null;')" //utility/mc_feature_flow:flow_kit_test
run "M5 leading shown on inner pages too" utility/mc_feature_flow/lib/src/flow_context.dart "(' || (inner?.canPop() ?? false)','')" //utility/mc_feature_flow:flow_kit_test
run "M6 AppConfig does not normalise" utility/mc_config/lib/src/app_config.dart "('apiBaseUrl = withTrailingSlash(apiBaseUrl)','apiBaseUrl = apiBaseUrl')" //utility/mc_config:app_config_test
run "M7 createApiDio does not normalise" utility/mc_api_client/lib/src/api_dio.dart "('baseUrl: withTrailingSlash(baseUrl),','baseUrl: baseUrl,')" //utility/mc_api_client:api_client_test
run "M8 createDio does not normalise" utility/mc_mocked_backend/lib/src/backend.dart "(\"baseUrl.endsWith('/') ? baseUrl : '\$baseUrl/'\",'baseUrl')" //utility/mc_mocked_backend:mocked_backend_test
run "M9 heightFor ignores hasSubtitle" utility/mc_ds_cards/lib/src/mc_media_card.dart "('(hasSubtitle ? McSpacing.xxs + line(_subtitleStyle) : 0)','(McSpacing.xxs + line(_subtitleStyle))')" //utility/mc_ds_cards:card_test
run "M10 arch check ignores testing.dart" tool/mc_arch_check/lib/src/arch_check.dart "(\"path == 'testing.dart' &&\",\"path == 'never.dart' &&\")" //tool/mc_arch_check:arch_check_test
