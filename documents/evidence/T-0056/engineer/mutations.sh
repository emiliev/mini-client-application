#!/bin/bash
# T-0056: mutation check of the store_home DB exemplar and its kit support.
#
# Every mutation edits one source file, runs the named test targets, and must
# make a test FAIL ("FAILED in" in Bazel's summary). Outcomes:
#   KILLED    a test failed.
#   BROKEN    the build did not complete ("Build did NOT complete", a compile,
#             analyzer or format error): NOT evidence, counted as a failure.
#   TIMEOUT   a test timed out: not a kill, counted as a failure.
#   SURVIVED  every test passed: a hole in the tests.
# The unmutated tree must pass first. The script REFUSES a dirty tree (any
# uncommitted or untracked file) and sets its restore trap before it edits
# anything; after each mutation the file is restored with `git checkout` and
# the restore is verified.
#
#   MC_TASK=T-0056 MC_ROLE=engineer documents/evidence/T-0056/engineer/mutations.sh
#   MC_ONLY="M01 W2" ...   only the named mutations (after the baseline)
#   MC_CHECK_ONLY=1 ...    only check that every pattern applies (no Bazel)
#
# Exit 0 only if every mutation was applied and killed. The log goes to
# /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TASK="${MC_TASK:-T-0056}"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-$TASK-$ROLE}"
LOG="/tmp/mc-$TASK-$ROLE-mutations.log"
CHECK_ONLY="${MC_CHECK_ONLY:-}"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

if [[ -z "$CHECK_ONLY" && -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the tree is dirty (commit or remove these first):" >&2
  git status --short >&2
  exit 2
fi
: > "$LOG"

F=feature/store/store_home/lib/src
BLOC=$F/presentation/bloc
W=app/wiring/commerce_wiring/lib/src
FILES=(
  "$BLOC/store_section_bloc.dart" "$BLOC/banners_bloc.dart" "$BLOC/deals_bloc.dart"
  "$BLOC/categories_bloc.dart" "$BLOC/featured_bloc.dart" "$BLOC/cart_summary_bloc.dart"
  "$BLOC/category_products_bloc.dart" "$BLOC/open_category.dart"
  "$F/presentation/page/store_home_page.dart" "$F/flow/store_home_flow.dart"
  "$F/domain/repository/store_home_repository.dart" "$F/domain/model/store_mapper.dart"
  "$F/domain/model/store.dart"
  "$W/navigators/store_home_navigator_impl.dart" "$W/di/commerce_wiring_di_initializer.dart"
  "$W/routes/store_routes.dart" app/wiring/app_core/lib/src/locations/app_locations.dart
  utility/mc_formatters/lib/src/formatters.dart utility/mc_formatters/lib/src/money.dart
  utility/mc_analytics/lib/src/route_observer.dart utility/mc_analytics/lib/src/analytics.dart
  utility/mc_feature_flow/lib/src/feature_flow.dart utility/mc_feature_flow/lib/src/flow_context.dart
  utility/mc_test_utils/lib/src/backend_harness.dart utility/mc_test_utils/lib/src/test_flags.dart
)
restore_all() { git checkout -- "${FILES[@]}" 2>/dev/null; }
trap restore_all EXIT INT TERM

T_BDD=//feature/store/store_home:bdd_test
T_FEAT="$T_BDD //feature/store/store_home:contract_test //feature/store/store_home:flow_scope_test"
T_WIRE="//app/wiring/commerce_wiring:routes_test //app/wiring/app_core:app_layer_test"
T_FMT=//utility/mc_formatters:formatters_test
T_AN="//utility/mc_analytics:flow_observer_test //utility/mc_analytics:route_observer_test //utility/mc_analytics:di_test //app/mini_client:analytics_screens_test"
T_FF=//utility/mc_feature_flow:feature_flow_test
T_TU="//utility/mc_test_utils:harness_test //utility/mc_test_utils:flags_container_test //utility/mc_test_steps:flag_steps_test"

run() { bz test --nocache_test_results --test_timeout=900 "$@" 2>&1 | tr '\r' '\n'; }

if [[ -z "$CHECK_ONLY" ]]; then
  base="$(run $T_FEAT $T_WIRE $T_FMT $T_AN $T_FF $T_TU)"
  if grep -q -a -E "FAILED|NO STATUS|^ERROR|Build did NOT complete" <<< "$base"; then
    say "BASELINE FAILS"
    grep -a -E "FAILED|^ERROR|Build did NOT" <<< "$base" | tee -a "$LOG"
    exit 1
  fi
  say "baseline: PASS"
fi

rc=0; n=0; killed=0
# mutate ID "what" file "targets" old new [old new ...]
mutate() {
  local id="$1" what="$2" file="$3" targets="$4"; shift 4
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then return; fi
  n=$((n + 1))
  /usr/bin/python3 -I - "$file" "$@" <<'EOF'
import sys
path, pairs = sys.argv[1], sys.argv[2:]
s = open(path).read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if s.count(old) != 1:
        print("PATTERN MATCHES %d TIMES: %r" % (s.count(old), old)); sys.exit(3)
    s = s.replace(old, new)
open(path, "w").write(s)
EOF
  if [[ $? -ne 0 ]]; then
    say "$id $what: NOT APPLIED"; rc=1; git checkout -- "$file"; return
  fi
  if [[ -n "$CHECK_ONLY" ]]; then
    say "$id $what: applies"; git checkout -- "$file"; return
  fi
  [[ "$file" == *.dart ]] && fvm dart format "$file" > /dev/null
  local out; out="$(run $targets)"
  if grep -q -a -E "Build did NOT complete|^ERROR|FAILED TO BUILD" <<< "$out"; then
    say "$id $what: BROKEN (build failed: not evidence)"; rc=1
  elif grep -q -a "FAILED in" <<< "$out"; then
    local first; first="$(grep -a -m1 'FAILED in' <<< "$out" | awk '{print $1}')"
    say "$id $what: KILLED ($first)"; killed=$((killed + 1))
  elif grep -q -a "TIMEOUT in" <<< "$out"; then
    say "$id $what: TIMEOUT (not a kill)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}

# --- the section mechanics (StoreSectionBloc) -----------------------------
S="$BLOC/store_section_bloc.dart"
mutate M01 "a stale answer is applied (no generation check)" "$S" "$T_BDD" \
  'if (result == null || generation != _generation || isClosed) {' 'if (result == null || isClosed) {'
mutate M02 "a refresh shows the skeleton instead of keeping the content" "$S" "$T_BDD" \
  '    if (!keepShown) {' '    if (keepShown || !keepShown) {'
mutate M03 "an empty answer shows as ready" "$S" "$T_BDD" \
  '      if (isEmptyData(data)) {' '      if (isEmptyData(data) && !isEmptyData(data)) {'
mutate M04 "section_viewed on every ready, not once per visit" "$S" "$T_BDD" \
  '      if (!_viewed) {' '      if (!_viewed || _viewed) {'
mutate M05 "section_viewed for a failed section too" "$S" "$T_BDD" \
  '    }, (error) => emit(failureState(error)));' \
  $'    }, (error) {\n      emit(failureState(error));\n      tracker.sectionViewed(section);\n    });'
mutate M06 "the open guard ignores the target" "$S" "$T_BDD" \
  '(_openGuard?.isActive ?? false) && _openTarget == target' '(_openGuard?.isActive ?? false)'
mutate M07 "the open guard lasts 501 ms" "$S" "$T_BDD" \
  'const Duration openGuard = Duration(milliseconds: 500);' 'const Duration openGuard = Duration(milliseconds: 501);'
mutate M08 "the open guard lasts 499 ms" "$S" "$T_BDD" \
  'const Duration openGuard = Duration(milliseconds: 500);' 'const Duration openGuard = Duration(milliseconds: 499);'
mutate M09 "the open guard never starts" "$S" "$T_BDD" \
  '    _openGuard = Timer(openGuard, () {});' '    _openGuard = Timer(Duration.zero, () {});'

# --- the five section blocs -----------------------------------------------
mutate M10 "a comic banner opens nothing" "$BLOC/banners_bloc.dart" "$T_BDD" \
  $'        _navigator.openComic(id);\n' ''
mutate M11 "a category banner's page is named before the lookup" "$BLOC/banners_bloc.dart" "$T_BDD" \
  '_flow.openCategory(OpenCategory(id: id));' "_flow.openCategory(OpenCategory(id: id, name: 'Category'));"
mutate M12 "a search banner is tracked as a comic" "$BLOC/banners_bloc.dart" "$T_BDD" \
  'tracker.itemTapped(section, StoreItemKind.search, query);' 'tracker.itemTapped(section, StoreItemKind.comic, query);'
mutate M13 "deals Retry ignores the state (double tap loads twice)" "$BLOC/deals_bloc.dart" "$T_BDD" \
  $'      case _Retry():\n        if (state is _Failure) {' $'      case _Retry():\n        if (state is _Failure || state is _Loading) {'
mutate M14 "deals count down a day off the injected clock" "$BLOC/deals_bloc.dart" "$T_BDD //feature/store/store_home:flow_scope_test" \
  '    final now = _clock.now();' '    final now = _clock.now().add(const Duration(days: 1));'
mutate M15 "a deal tap is tracked with the wrong id" "$BLOC/deals_bloc.dart" "$T_BDD" \
  "tracker.itemTapped(section, StoreItemKind.comic, '\${id.value}');" "tracker.itemTapped(section, StoreItemKind.comic, 'deal');"
mutate M16 "a category opens without its name" "$BLOC/categories_bloc.dart" "$T_BDD" \
  'OpenCategory(id: category.id, name: category.name),' 'OpenCategory(id: category.id),'
mutate M17 "a second category tap replaces the first" "$BLOC/open_category.dart" "$T_BDD" \
  '    if (state.category == null) {' '    if (state.category == null || state.rootCategory == null) {'
mutate M18 "a featured comic opens nothing" "$BLOC/featured_bloc.dart" "$T_BDD" \
  $'          _navigator.openComic(product.id);\n' ''

# --- the cart: the session rules ------------------------------------------
C="$BLOC/cart_summary_bloc.dart"
mutate C01 "an answer for a session that is gone is shown" "$C" "$T_BDD" \
  '    if (_session.epoch == epoch) {' '    if (_session.epoch == epoch || epoch >= 0) {'
mutate C02 "a double tap asks to sign in twice" "$C" "$T_BDD" \
  '    if (state is! _SignedOut) {' '    if (state is! _SignedOut && state is! _SigningIn) {'
mutate C03 "a declined sign-in leaves the section waiting" "$C" "$T_BDD" \
  'if (_session.epoch != _shownEpoch || state is _SigningIn) {' 'if (_session.epoch != _shownEpoch) {'
mutate C04 "a session change elsewhere is ignored" "$C" "$T_BDD" \
  'if (_shownEpoch != null && _session.epoch != _shownEpoch) {' 'if (_shownEpoch != null && _session.epoch != _shownEpoch && _shownEpoch == null) {'
mutate C05 "pull to refresh asks for the cart while signed out" "$C" "$T_BDD" \
  $'      case _Refresh(:final done):\n        if (_session.isSignedIn) {' $'      case _Refresh(:final done):\n        if (_session.isSignedIn || !_session.isSignedIn) {'
mutate C06 "signed out still asks for the cart" "$C" "$T_BDD" \
  '    if (!_session.isSignedIn) {' '    if (!_session.isSignedIn && _shownEpoch == null) {'
mutate C07 "an empty cart shows as ready" "$C" "$T_BDD" \
  'bool isEmptyData(CartSummary data) => data.itemCount == 0;' 'bool isEmptyData(CartSummary data) => data.itemCount < 0;'

# --- the category page ----------------------------------------------------
P="$BLOC/category_products_bloc.dart"
mutate P01 "an unknown category is a failure, not not-found" "$P" "$T_BDD" \
  $'        PagedState(items: [], failure: ApiNotFound()) =>\n          const CategoryProductsState.notFound(),\n' ''
mutate P02 "the looked-up name never titles the page" "$P" "$T_BDD" \
  '    if (name != null) {' '    if (name != null && name.isEmpty) {'
mutate P03 "the end of the list loads no next page" "$P" "$T_BDD" \
  $'      case _LoadMore():\n        await _paging.loadMore();' $'      case _LoadMore():\n        await _paging.retry();'
mutate P04 "a product tap opens nothing" "$P" "$T_BDD" \
  $'          _navigator.openComic(product.id);\n' ''

# --- the page, the flow, the data -----------------------------------------
mutate G01 "the featured flag is ignored" "$F/presentation/page/store_home_page.dart" "$T_BDD" \
  $'    storeHomeFeatured,\n  );' $'    storeHomeFeatured,\n  ) || true;'
mutate G02 "the visit's start skips the cart (it loads only when scrolled to)" "$F/presentation/page/store_home_page.dart" "$T_BDD" \
  $'    context.read<CartSummaryBloc>().add(const CartSummaryEvent.load());\n' ''
mutate G03 "pull to refresh skips the deals" "$F/presentation/page/store_home_page.dart" "$T_BDD" \
  $'      one((d) => context.read<DealsBloc>().add(DealsEvent.refresh(d))),\n' ''
mutate G04 "the flow ignores the injected clock" "$F/flow/store_home_flow.dart" "$T_BDD //feature/store/store_home:flow_scope_test" \
  '..registerSingleton<StoreClock>(StoreClock(clock)),' '..registerSingleton<StoreClock>(StoreClock(DateTime.now)),'
mutate D01 "the cart read is not pinned to its session" "$F/domain/repository/store_home_repository.dart" "$T_BDD" \
  '(await _api.getCart(extras: authPinned(epoch))).toDomain(),' '(await _api.getCart(extras: authPinned(epoch + 0 * epoch).isEmpty ? const {} : const {})).toDomain(),'
mutate D02 "every page is requested at offset 0" "$F/domain/repository/store_home_repository.dart" "$T_BDD" \
  '      offset: request.offset,' '      offset: 0 * request.offset,'
mutate D03 "the deal price is the original price" "$F/domain/model/store_mapper.dart" "$T_FEAT" \
  '      dealPrice: Money(dealPriceCents, money),' '      dealPrice: Money(originalPriceCents, money),'
mutate D04 "a product never has a deal price" "$F/domain/model/store_mapper.dart" "$T_FEAT" \
  '        final cents? => Money(cents, money),' '        final cents? => cents < 0 ? Money(cents, money) : null,'
mutate D05 "a search banner leads to a comic" "$F/domain/model/store_mapper.dart" "$T_FEAT" \
  "('search', _, _, final q?) => BannerTarget.search(q)," "('search', _, _, final q?) => BannerTarget.comic(ComicId(q.length)),"
mutate D06 "days left round up" "$F/domain/model/store.dart" "$T_FEAT" \
  'int daysLeftAt(DateTime now) => endsAt.difference(now).inDays;' 'int daysLeftAt(DateTime now) => (endsAt.difference(now).inHours + 23) ~/ 24;'

# --- the wiring -----------------------------------------------------------
N="$W/navigators/store_home_navigator_impl.dart"
mutate W1 "openSearch drops the query" "$N" "$T_WIRE" \
  'push(AppLocations.search(query))' 'push(AppLocations.search())'
mutate W2 "openCart pushes the store" "$N" "$T_WIRE" \
  'push(const StoreCartRoute().location)' 'push(const StoreRoute().location)'
mutate W3 "the sign-in sheet loses the cart's reason" "$N" "$T_WIRE" \
  "reason: 'to see your cart'," "reason: 'to keep your favourites',"
mutate W4 "the store counts down against the device time in the app" "$W/di/commerce_wiring_di_initializer.dart" "$T_WIRE" \
  '  if (!getIt.isRegistered<MockBackend>()) {' '  if (getIt.isRegistered<MockBackend>()) {'
mutate W5 "a category link opens the store home" "$W/routes/store_routes.dart" "$T_WIRE" \
  'diContainer<CommerceRouteTargets>().store(category: id);' 'diContainer<CommerceRouteTargets>().store(category: id.isEmpty ? id : null);'
mutate W6 "AppLocations.storeCategory does not encode the id" app/wiring/app_core/lib/src/locations/app_locations.dart "$T_WIRE" \
  "'/store/categories/\${Uri.encodeComponent(id)}';" "'/store/categories/\$id';"

# --- the money formatter (mc_formatters) ----------------------------------
mutate F1 "money always has 2 decimals" utility/mc_formatters/lib/src/formatters.dart "$T_FMT" \
  '  decimalDigits: money.currency.fractionDigits,' '  decimalDigits: 2,'
mutate F2 "money ignores the locale" utility/mc_formatters/lib/src/formatters.dart "$T_FMT" \
  $'NumberFormat.simpleCurrency(\n  locale: locale,' $'NumberFormat.simpleCurrency(\n  locale: \'en\','
mutate F3 "the minor-unit divisor is 100 per digit" utility/mc_formatters/lib/src/money.dart "$T_FMT" \
  '      divisor *= 10;' '      divisor *= 100;'
mutate F4 "Currency.parse accepts lower case" utility/mc_formatters/lib/src/money.dart "$T_FMT" \
  '      if (currency.code == code) {' '      if (currency.code == code.toUpperCase()) {'

# --- the kit: screens inside a flow, the tracker port ---------------------
R=utility/mc_analytics/lib/src/route_observer.dart
mutate K1 "a flow's first page is tracked again" "$R" "$T_AN" \
  'if (previousTopRoute == null && _reported[hostRoute] == name) {' 'if (previousTopRoute == null && _reported[hostRoute] == name && name.isEmpty) {'
mutate K2 "a flow page is tracked while hidden under another screen" "$R" "$T_AN" \
  '      if (!hostRoute.isCurrent) {' '      if (!hostRoute.isCurrent && name.isEmpty) {'
mutate K3 "the route observer ignores what the flow shows" "$R" "$T_AN" \
  '    final flowPage = _flowScreens[topRoute];' '    final flowPage = topRoute.isActive ? null : _flowScreens[topRoute];'
mutate K4 "the route observer does not record what it tracked" "$R" "$T_AN" \
  $'    _reported[route] = name;\n    analytics.screen(name);' $'    analytics.screen(name);'
mutate K5 "the tracker port's screens go nowhere" utility/mc_analytics/lib/src/analytics.dart "$T_AN" \
  '  void trackScreen(String name) => screen(name);' $'  void trackScreen(String name) {\n    if (name.isEmpty) {\n      screen(name);\n    }\n  }'
mutate K6 "FeatureFlow drops its observers" utility/mc_feature_flow/lib/src/feature_flow.dart "$T_FF" \
  $'    _navigatorObserver,\n    ...widget.observers,' $'    _navigatorObserver,\n    if (widget.observers.isEmpty) ...widget.observers,'

# --- the test kit: holdNext and the flag stub -----------------------------
mutate U1 "holdNext holds every request" utility/mc_test_utils/lib/src/backend_harness.dart "$T_TU $T_BDD" \
  '    taken = once;' '    taken = once && !once;'
mutate U2 "the flag stub never reads the snapshot" utility/mc_test_utils/lib/src/test_flags.dart "$T_TU" \
  '      flag.codec.decode(_remote[flag.key]) ?? flag.defaultValue;' '      flag.codec.decode(_remote[flag.key]) == null ? flag.defaultValue : flag.defaultValue;'

# --- review round (TL /code-review items 1 to 6) ---------------------------
mutate V01 "a dropped cart answer does not reload (item 1)" "$C" "$T_BDD" \
  $'    add(const _SessionChanged());\n    return null;' $'    return null;'
mutate V02 "the store page starts while hidden (item 2)" "$F/presentation/page/store_home_page.dart" "$T_FEAT //app/mini_client:analytics_screens_test" \
  '(FlowScope.maybeOf(context)?.outerIsCurrent ?? true);' '(FlowScope.maybeOf(context)?.outerIsCurrent ?? true) || true;'
mutate V03 "the store page starts again on every showing (item 2)" "$F/presentation/page/store_home_page.dart" "$T_FEAT //app/mini_client:analytics_screens_test" \
  '    if (shown && !_started) {' '    if (shown) {'
mutate V04 "the cart loads on a session event before the visit starts (item 2)" "$C" "$T_BDD //feature/store/store_home:flow_scope_test" \
  'if (_shownEpoch != null && _session.epoch != _shownEpoch) {' 'if (_session.epoch != _shownEpoch) {'
mutate V05 "a flow page changed under a popup is never tracked (item 3)" "$R" "$T_AN" \
  '      if (flowPage != null && flowPage != _reported[topRoute]) {' '      if (flowPage != null && flowPage != _reported[topRoute] && flowPage.isEmpty) {'
mutate V06 "the flow observer depends on the host route (item 4)" "$R" "$T_AN" \
  '    final hostRoute = host(context);' '    final hostRoute = ModalRoute.of(context);'
mutate V07 "FeatureFlow does not publish its route (item 4)" utility/mc_feature_flow/lib/src/feature_flow.dart "$T_FF $T_AN" \
  '      outerRoute: route,' '      outerRoute: null,'
mutate V08 "FlowScope does not notify a status flip (item 2, 4)" utility/mc_feature_flow/lib/src/flow_context.dart "$T_FF //feature/store/store_home:flow_scope_test" \
  $'      outerIsCurrent != oldWidget.outerIsCurrent ||\n' ''
mutate V09 "an ended deal is shown (item 5)" "$BLOC/deals_bloc.dart" "$T_FEAT" \
  '            if (deal.runsAt(now)) deal,' '            if (deal.runsAt(now) || !deal.runsAt(now)) deal,'
mutate V10 "a deal still runs exactly at its end (item 5)" "$F/domain/model/store.dart" "$T_FEAT" \
  'bool runsAt(DateTime now) => endsAt.isAfter(now);' 'bool runsAt(DateTime now) => !endsAt.isBefore(now);'
mutate V11 "an invalid flow page name is tracked (item 6)" "$R" "$T_AN" \
  '    if (!AnalyticsRules.isValidName(name)) {' '    if (name.isEmpty) {'
mutate V12 "an invalid flow page is not recorded, so the page before it is reported (item 6)" "$R" "$T_AN" \
  $'      _flowScreens[hostRoute] = name;\n' $'      if (AnalyticsRules.isValidName(name)) {\n        _flowScreens[hostRoute] = name;\n      }\n'

say ""
say "mutations: $n, killed: $killed"
[[ $rc -eq 0 && $n -gt 0 && $killed -eq $n ]] && say "RESULT: PASS" || say "RESULT: FAIL"
exit $rc
