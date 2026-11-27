#!/bin/bash
# T-0052 engineer mutation checks: each mutation of mc_feature_flags or
# mc_fixtures_platform must turn at least one test red.
#
#   MC_TASK=T-0052 MC_ROLE=engineer documents/evidence/T-0052/engineer/mutations.sh
#
# Outcomes of one mutation:
#   KILLED    the build completed and at least one test target reported
#             "FAILED in" (a timeout is not a kill).
#   BROKEN    "Build did NOT complete" (a compile, analyzer or format error of
#             the mutant itself), a timeout, or a pattern that was not found.
#             A broken mutant proves nothing, so it fails the run.
#   SURVIVED  the build completed and every test passed.
# The run fails (exit 1) unless every mutation was KILLED.
#
# Refuses to run on a dirty tree: every mutation is undone with
# `git checkout -- <the two packages>`, which would also discard uncommitted
# edits. The restore trap is set before the first edit, so Ctrl-C, a failing
# command or a kill leaves the packages as committed. The log goes to stdout
# (tee it outside the tree). MC_DRY=1 only checks that every pattern applies;
# MC_ONLY=<regex> runs only the mutations whose name matches.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
: "${MC_TASK:?set MC_TASK, e.g. T-0052}"
: "${MC_ROLE:?set MC_ROLE, e.g. engineer}"
FF=utility/mc_feature_flags
FP=utility/mc_fixtures_platform
SS=utility/mc_session
if [[ -n "$(git status --porcelain)" ]]; then
  echo "refusing to run: the working tree is not clean" >&2
  git status --short >&2
  exit 2
fi
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="$(mktemp -t "mc-$MC_TASK-$MC_ROLE-mut.XXXXXX")"
restore() { git checkout -- "$FF" "$FP" "$SS" 2>/dev/null; }
# Set before any edit.
trap 'restore; rm -f "$LOG"' EXIT
trap 'echo "interrupted" >&2; exit 130' INT TERM
killed=0
survived=0
broken=0
total=0

# Test target patterns, one per package (a mutation runs only its package).
tests_for() {
  case "$1" in
    "$FF"/*) echo "//$FF/..." ;;
    "$SS"/*) echo "//$FF/... //$SS/..." ;;
    *) echo "//$FP/..." ;;
  esac
}

run_tests() {
  tool/bazelw --output_base="$OB" test --keep_going --test_timeout=90 $(tests_for "$1") > "$LOG" 2>&1
}

plain() { tr '\r' '\n' < "$LOG"; }

# mutate <name> <file> <old> <new>   (replaces the first occurrence)
mutate() {
  local name="$1" file="$2" old="$3" new="$4"
  # MC_ONLY=<regex> runs only the mutations whose name matches (iteration).
  if [[ -n "${MC_ONLY:-}" && ! "$name" =~ $MC_ONLY ]]; then return; fi
  total=$((total + 1))
  echo "=== $name"
  if ! python3 -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if s.count(old) < 1:
    sys.exit("pattern not found: " + old)
open(p, "w").write(s.replace(old, new, 1))
' "$file" "$old" "$new"; then
    echo "    BROKEN: PATTERN NOT FOUND"; broken=$((broken + 1)); restore; return
  fi
  if git diff --quiet -- "$file"; then
    echo "    BROKEN: the mutation changed nothing"; broken=$((broken + 1)); restore; return
  fi
  if [[ -n "${MC_DRY:-}" ]]; then
    echo "    pattern applies"; restore; return
  fi
  # The build checks formatting, so a mutation is formatted like the source.
  fvm dart format "$file" > /dev/null 2>&1
  run_tests "$file"
  local failed
  failed="$(plain | grep -aE '^//.*FAILED in' | sed 's/ *FAILED in.*//' | tr '\n' ' ')"
  if plain | grep -aq 'Build did NOT complete'; then
    echo "    BROKEN: build did not complete (does not count as killed)"
    plain | grep -aE 'error|info -|warning' | head -3
    broken=$((broken + 1))
  elif [[ -n "$failed" ]]; then
    echo "    KILLED by: $failed"
    killed=$((killed + 1))
  elif plain | grep -aqE 'TIMEOUT in'; then
    echo "    BROKEN: a test timed out (not a kill)"
    broken=$((broken + 1))
  else
    echo "    SURVIVED"; survived=$((survived + 1))
  fi
  restore
}

# Baseline: the unmutated tree must pass.
if [[ -z "${MC_DRY:-}" ]]; then
  run_tests "$FF/x" && run_tests "$FP/x" && run_tests "$SS/x" || { echo "BASELINE FAILS"; plain | tail -20; exit 1; }
  echo "baseline PASS"
fi

F=$FF/lib/src/feature_flags.dart
FL=$FF/lib/src/feature_flag.dart
BK=$FF/lib/src/bucketing.dart
RS=$FF/lib/src/remote_snapshot.dart
DI=$FF/lib/src/feature_flags_di_initializer.dart

# --- evaluation order: each source removed, reordered or mis-gated -----------
mutate "O1 overrides ignore the environment" $F 'bool get _overridesAllowed => !isReleaseLikeEnv(_env);' 'bool get _overridesAllowed => _env.isNotEmpty;'
mutate "O2 overrides are never accepted" $F 'bool get _overridesAllowed => !isReleaseLikeEnv(_env);' 'bool get _overridesAllowed => _env.isEmpty;'
mutate "O3 the remote value beats an override" $F 'final stored = _overrideFlags[flag.key];' 'final stored = (_remote?.flags.containsKey(flag.key) ?? false) ? null : _overrideFlags[flag.key];'
mutate "O4 a release-like env is only the word release" $FF/lib/src/feature_flag_overrides.dart 'bool isReleaseLikeEnv(String env) => !overridableEnvs.contains(env);' "bool isReleaseLikeEnv(String env) => env == 'release';"
mutate "R1 the remote value of this epoch is ignored" $F 'final snapshot = _remote ?? _lastKnownGood;' 'final snapshot = _lastKnownGood;'
mutate "R2 the last-known-good is ignored" $F 'final snapshot = _remote ?? _lastKnownGood;' 'final snapshot = _remote;'
mutate "R3 the last-known-good beats the remote value" $F 'final snapshot = _remote ?? _lastKnownGood;' 'final snapshot = _lastKnownGood ?? _remote;'
mutate "R4 a key the server omits falls back to the old value" $F '    // 4. the default
    return flag.defaultValue;' '    // 4. the default
    final old = _lastKnownGood?.flags[flag.key];
    return old is T ? old : flag.defaultValue;'
mutate "R5 the default is wrong: a null value counts as a value" $F 'if (raw != null) {
        final decoded = flag.codec.decode(raw);' 'if (snapshot.flags.containsKey(flag.key)) {
        final decoded = flag.codec.decode(raw);'
mutate "W1 a wrong-typed remote value is reported every time" $F 'if (_reported.add(id)) {' 'if (_reported.add(id) || id.isNotEmpty) {'
mutate "W2 a wrong-typed remote value is never reported" $F 'if (_reported.add(id)) {' "if (_reported.add(id) && !id.startsWith('remote:')) {"
mutate "W3 a wrong-typed override is never reported" $F 'if (_reported.add(id)) {' "if (_reported.add(id) && !id.startsWith('override:')) {"
mutate "W4 an int flag accepts a double" $FL 'int? decode(Object? raw) => raw is int ? raw : null;' 'int? decode(Object? raw) => raw is num ? raw.toInt() : null;'
mutate "W5 a bool flag accepts 1" $FL 'bool? decode(Object? raw) => raw is bool ? raw : null;' 'bool? decode(Object? raw) => raw is bool ? raw : (raw == 1 ? true : null);'
mutate "W6 a string flag accepts any value" $FL 'String? decode(Object? raw) => raw is String ? raw : null;' "String? decode(Object? raw) => raw == null ? null : '\$raw';"
mutate "W7 an enum name is matched case-insensitively" $FL 'if (value.name == raw) {' 'if (value.name.toLowerCase() == raw.toLowerCase()) {'
# --- the session epoch -------------------------------------------------------
mutate "E1 a result for an old epoch is applied" $F 'if (_disposed || epoch != _session.epoch) {
        return;' 'if (_disposed) {
        return;'
mutate "E2 the remote values of the old epoch are kept" $F '    _remote = null;
    _seenEpoch = epoch;' '    _seenEpoch = epoch;'
mutate "E3 another user's values are kept as last-known-good" $F '_lastKnownGood = userId == _seenUserId ?' "_lastKnownGood = userId == _seenUserId || userId != null ?"
mutate "E4 the same user's values are dropped on a new epoch" $F '_lastKnownGood = userId == _seenUserId ?' "_lastKnownGood = _seenUserId == '__never__' ?"
mutate "E5 value() does not notice a new epoch" $F 'T value<T extends Object>(FeatureFlag<T> flag) {
    _observeEpoch();' 'T value<T extends Object>(FeatureFlag<T> flag) {'
mutate "E6 the session stream does not trigger the refetch" $F '_authSubscription = _session.authState.listen((_) {
      _observeEpoch();
      _notify();' '_authSubscription = _session.authState.listen((_) {
      _notify();'
mutate "E7 a fetch joins an in-flight fetch of another epoch" $F 'if (running != null && running.epoch == epoch) {' 'if (running != null) {'
mutate "E8 refresh never shares a request" $F 'if (running != null && running.epoch == epoch) {' 'if (running != null && running.epoch == epoch && epoch < 0) {'
mutate "E9 a disposed instance still applies results" $F '_disposed = true;
    unawaited' '_disposed = false;
    unawaited'
mutate "E10 a failed fetch clears the remote values" $F 'if (snapshot == null) {' 'if (snapshot == null) {
        _remote = null;'
mutate "E11 the cache is written under another key" $F '_store.write(flagsCacheKey, snapshot.toJson())' "_store.write('\${flagsCacheKey}_x', snapshot.toJson())"
mutate "E12 the cache of another user is used" $RS 'if (json is! Map || json['"'"'userId'"'"'] != forUser) {' 'if (json is! Map) {'
mutate "E13 the first fetch is never started" $DI 'flags.start();' '// no start'
mutate "E14 boot waits for the first fetch" $DI 'flags.start();' 'await flags.refresh();'
mutate "E15 the reader port is not registered" $DI '..registerSingleton<FeatureFlagsReader>(flags)
      ' '
      '
mutate "E16 the environment is not taken from AppConfig" $DI 'env: getIt<AppConfig>().env,' "env: getIt<AppConfig>().build.isEmpty ? 'dev' : 'dev',"
# --- overrides ---------------------------------------------------------------
mutate "V1 set is accepted in a release-like env" $F 'final rejected = _rejected();
    if (rejected != null) {
      return rejected;
    }' 'final Result<void, FlagOverrideFailure>? rejected = null;
    if (rejected != null) {
      return rejected;
    }'
mutate "V2 clear removes another key" $F '_overrideFlags.remove(flag.key);' "_overrideFlags.remove('\${flag.key}_');"
mutate "V3 clearAll keeps the forced variants" $F '_forcedVariants.clear();' "_forcedVariants.remove('__none__');"
mutate "V4 set is not saved" $F '_overrideFlags[flag.key] = flag.codec.encode(value);
    _notify();
    return _saveOverrides();' '_overrideFlags[flag.key] = flag.codec.encode(value);
    _notify();
    return success(null);'
mutate "V5 an undeclared variant can be forced" $F 'if (!experiment.variants.any((v) => v.name == variant)) {' 'if (variant.isEmpty) {'
mutate "V6 a saved forced variant is not validated" $F 'if (variants.any((v) => v.name == forced)) {' 'if (forced.isNotEmpty) {'
mutate "V7 a forced variant is ignored" $F '          return forced;' '          return variants.first.name;'
# --- experiments and bucketing -----------------------------------------------
mutate "X1 remote weights are ignored" $F 'weights = scaled;' 'weights = [for (final v in variants) v.weight];'
mutate "X2 a variant the remote omits keeps its declared weight" $F 'remote[v.name] ?? 0' 'remote[v.name] ?? v.weight'
mutate "X3 remote weights with no positive weight are accepted" $F 'scaled.any((w) => w > 0)' 'scaled.isNotEmpty'
mutate "X4 the subject is always the install" $F '_session.userId ?? _install()' '_install()'
mutate "X5 the subject is a constant when signed out" $F '_session.userId ?? _install()' "_session.userId ?? (_installId == 'x' ? _install() : 'anonymous')"
mutate "X6 the install id is made again on every call" $F 'final existing = _installId;' "final existing = _installId == 'x' ? 'x' : null;"
mutate "X7 the install id is not saved" $F 'unawaited(_store.write(flagsInstallIdKey, id));' 'unawaited(Future<void>.value());'
mutate "B1 the FNV prime is wrong" $BK 'hash * 403' 'hash * 401'
mutate "B2 the FNV offset is wrong" $BK 'var hash = 2166136261;' 'var hash = 2166136260;'
mutate "B3 the hash adds instead of xor" $BK 'hash ^= byte;' 'hash += byte;'
mutate "B4 the bucket count is 9999" $BK '% bucketCount;' '% (bucketCount - 1);'
mutate "B5 String.hashCode is mixed in" $BK "fnv1a32(utf8.encode('\$experimentKey:\$subjectId')) % bucketCount" "(fnv1a32(utf8.encode('\$experimentKey:\$subjectId')) ^ experimentKey.hashCode) % bucketCount"
mutate "B6 the separator is a pipe" $BK "'\$experimentKey:\$subjectId'" "'\$experimentKey|\$subjectId'"
mutate "B7 the cumulative bound is inclusive" $BK 'if (bucket < cumulative * bucketCount ~/ total) {' 'if (bucket <= cumulative * bucketCount ~/ total) {'
mutate "B8 no positive weight picks the last variant" $BK '  if (total <= 0) {
    return variants.first.name;' '  if (total <= 0) {
    return variants.last.name;'
mutate "B9 weights are not scaled to 10000" $BK 'cumulative * bucketCount ~/ total' 'cumulative * bucketCount ~/ (total + 1)'
# --- registry and codecs -----------------------------------------------------
mutate "G1 a duplicate flag key is accepted" $FL 'if (_flags.containsKey(flag.key)) {
      throw' "if (_flags.containsKey('\${flag.key}_')) {
      throw"
mutate "G2 a different flag may reuse a key" $FL '} else if (!identical(known, flag) && known != flag) {' '} else if (!identical(known, flag) && known != flag && flag.key.isEmpty) {'
mutate "G3 a duplicate experiment key is accepted" $FL 'if (_experiments.containsKey(experiment.key)) {' "if (_experiments.containsKey('\${experiment.key}_')) {"
mutate "G4 flag equality ignores the default" $FL '          other.defaultValue == defaultValue &&
' ''
mutate "G5 a blank key is accepted" $FL 'if (flag.key.trim().isEmpty) {' 'if (flag.key.isEmpty) {'
mutate "G6 a negative weight is accepted" $FL 'if (variant.weight < 0) {' 'if (variant.weight < -1) {'
mutate "G7 an experiment without variants is accepted" $FL 'if (experiment.variants.isEmpty) {' 'if (experiment.variants.length < 0) {'
mutate "S1 a body without a flags map is accepted" $RS "body is! Map || body['flags'] is! Map" 'body is! Map'
mutate "S2 a fractional weight is accepted" $RS 'weight is! int || weight < 0) {
        return null;
      }
      weights[name] = weight;' 'weight is! num || weight < 0) {
        return null;
      }
      weights[name] = weight.toInt();'
mutate "S3 a negative weight is accepted" $RS 'weight is! int || weight < 0' 'weight is! int || weight < -1'
mutate "S4 a variant that is not a map is not rejected" $RS 'if (variant is! Map) {' 'if (variant is! Map && variant != 5) {'
# --- fixtures ----------------------------------------------------------------
D=$FP/lib/src/data/flags.dart
H=$FP/lib/src/handlers/flags_handlers.dart
M=$FP/lib/src/domain.dart
S=$FP/lib/src/fixture_sets.dart
mutate "P1 u-100 is not targeted" $D "'u-100': {'search.layout': 'list', 'store.promo_banner': true}," "'u-100': {},"
mutate "P2 u-101 gets the anonymous page size" $D "'u-101': {'catalogue.page_size': 40}," "'u-101': {},"
mutate "P3 the zero weight becomes 1" $D "{'name': 'hint', 'weight': 0}," "{'name': 'hint', 'weight': 1},"
mutate "P4 the malformed set is well-typed" $D "'catalogue.page_size': 'twenty'," "'catalogue.page_size': 20,"
mutate "P5 a missing bearer is a 401" $H 'return MockResponse.ok(flagsBodyDefault(user?.id));' "return user == null ? MockResponse.error(401, 'unauthenticated', 'x') : MockResponse.ok(flagsBodyDefault(user.id));"
mutate "P6 the empty set serves the default body" $H 'MockResponse.ok(flagsBodyEmpty());' 'MockResponse.ok(flagsBodyDefault(null));'
mutate "P7 the server_error set answers 503" $H '      500,
      '"'"'injected_failure'"'"',' '      503,
      '"'"'injected_failure'"'"','
mutate "P8 the server_error scenario answers 502" $M 'FailureKind.http(500)' 'FailureKind.http(502)'
mutate "P9 the malformed scenario serves the default" $M "overrides: {'GET /v1/flags': handlers.malformedFlags}," "overrides: {'GET /v1/flags': handlers.defaultFlags},"
mutate "P10 the route is misspelled" $M "const List<String> platformRouteManifest = ['GET /v1/flags'];" "const List<String> platformRouteManifest = ['GET /v1/flag'];"
mutate "P11 a set is renamed" $S "'platform.flags_malformed': _malformed," "'platform.malformed': _malformed,"
mutate "P12 the empty scenario is dropped" $M "    'platform.empty': MockScenario(
      'platform.empty',
      overrides: {'GET /v1/flags': handlers.emptyFlags},
    )," ''

# --- review round -------------------------------------------------------------
SE=$SS/lib/src/session.dart
mutate "C1 a remote weight above the cap is accepted" $RS 'weight > maxVariantWeight ||' ''
mutate "C2 the cap itself is refused" $RS 'weight > maxVariantWeight ||' 'weight >= maxVariantWeight ||'
mutate "C3 a declared weight above the cap is accepted" $FL 'variant.weight < 0 || variant.weight > maxVariantWeight' 'variant.weight < 0'
mutate "C4 the cap is 10^15" $BK 'const int maxVariantWeight = 1000000000;' 'const int maxVariantWeight = 1000000000000000;'
mutate "H1 the epoch stream is not listened to" $F 'if (session is SessionEpochs) {' 'if (session is SessionEpochs && session.epochChanges.isBroadcast && _seenEpoch < 0) {'
mutate "H2 the epoch listener does not observe" $F '_epochSubscription = session.epochChanges.listen((_) {
        _observeEpoch();' '_epochSubscription = session.epochChanges.listen((_) {
        _seenEpoch.hashCode;'
mutate "H3 a sign-in announces no epoch" $SE '_epoch++;
    _announceEpoch();
    if (changed) {' '_epoch++;
    if (changed) {'
mutate "H4 a sign-out announces no epoch" $SE '_epoch++;
      _announceEpoch();
      _announce(AuthStatus.signedOut);' '_epoch++;
      _announce(AuthStatus.signedOut);'
mutate "D1 dispose leaves the watch streams open" $F 'unawaited(controller.close());' 'unawaited(Future<void>.value());'
mutate "D2 a fetch after dispose is sent" $F 'if (_disposed) {
      return Future<void>.value();
    }
    final epoch' 'if (_disposed && _watchers.length > 99) {
      return Future<void>.value();
    }
    final epoch'
mutate "D3 a watch after dispose is a live stream" $F 'if (_disposed) {
      return Stream<T>.fromIterable([value(flag)]);' 'if (_disposed && _watchers.length > 99) {
      return Stream<T>.fromIterable([value(flag)]);'
mutate "N1 a taken key makes set throw" $F '} on DuplicateFlagKeyError catch (error) {' '} on StateError catch (error) {'
mutate "N2 a blank key makes set throw" $F '} on ArgumentError catch (error) {' '} on RangeError catch (error) {'
mutate "I1 a failed install-id save is not retried" $F '_saveInstallId(); // an earlier save failed: try again' '// no retry'
mutate "I2 a saved install id is saved again and again" $F '(_) => _installIdSaved = true,' '(_) => _installIdSaving = false,'
mutate "K1 flag and experiment reports share a key" $F "'remote:experiment:\$key',
          'The remote weights of \$key are malformed'," "'remote:flag:\$key',
          'The remote weights of \$key are malformed',"
mutate "K2 an empty variants list is not malformed" $RS 'if (variants is! List || variants.isEmpty) {' 'if (variants is! List) {'
mutate "K3 a repeated variant name is accepted" $RS 'weights.containsKey(name)' 'weights.length > 999'
mutate "Y1 the cache stays on disk when the user changes" $F 'if (userId != _seenUserId) {' "if (userId == '__never__') {"
mutate "Y2 another cache file is deleted" $F '_store.delete(flagsCacheKey)' "_store.delete('\${flagsCacheKey}_x')"
mutate "Y3 the cache is deleted on a same-user sign-in too" $F 'if (userId != _seenUserId) {' 'if (userId != _seenUserId || epoch > 0) {'

echo
echo "TOTAL $total  KILLED $killed  SURVIVED $survived  BROKEN $broken"
[[ $survived -eq 0 && $broken -eq 0 && $killed -eq $total ]]
