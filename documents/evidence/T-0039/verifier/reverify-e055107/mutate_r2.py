# T-0039 Verifier re-verification mutations at e055107. One mutation (or one
# named set of edits) at a time, original targets uncached, files restored.
# Reports KILLED (with the failing targets and whether by FAILED or TIMEOUT
# and the slowest failing target's time), BUILD-ERROR or SURVIVED.
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path('/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a6e11cab586c62c97')
OB = '--output_base=/tmp/mc-ob-T-0039-verifier'
AUTH = ['//utility/mc_api_auth:auth_interceptor_test', '//utility/mc_api_auth:auth_races_test',
        '//utility/mc_api_auth:auth_api_test']
SESS = ['//utility/mc_session:session_test', '//utility/mc_session:session_di_test']
TU = ['//utility/mc_test_utils:auth_container_test', '//utility/mc_test_utils:isolation_test']
BOOT = ['//app/wiring/app_core:boot_test']
IC = 'utility/mc_api_auth/lib/src/auth_interceptor.dart'
SS = 'utility/mc_session/lib/src/session.dart'
DI = 'utility/mc_session/lib/src/session_di_initializer.dart'
TC = 'utility/mc_test_utils/lib/src/test_container.dart'

ON_REQ = ('      if (ours && options.extra[_epoch] != _reader.epoch && token != null) {',
          '      if (token == \'mc-never\' && ours && options.extra[_epoch] != _reader.epoch && token != null) {')
PRE = ('        epoch is! int ||\n        epoch != _reader.epoch) {', '        epoch is! int) {')
POST = ('      if (epoch != _reader.epoch) {\n        // Signed out', '      if (epoch < 0) {\n        // Signed out')

M = [
    ('E1 updateTokens ignores the epoch', [(SS, '(epoch != null && epoch != _epoch)', '(epoch != null && epoch < -1)')], SESS + AUTH),
    ('E2 signOut ignores ifEpoch', [(SS, 'if (ifEpoch != null && ifEpoch != _epoch) {', 'if (ifEpoch != null && ifEpoch < -1) {')], SESS + AUTH),
    ('E3 one shared refresh across epochs (epoch compare dropped in _refreshFor)', [(IC, 'if (current != null && current.epoch == epoch) {', 'if (current != null) {')], AUTH),
    ('X1 onRequest epoch check off', [(IC,) + ON_REQ], AUTH),
    ('X2 onError pre-refresh epoch check off', [(IC,) + PRE], AUTH),
    ('X3 onError post-refresh epoch check off', [(IC,) + POST], AUTH),
    ('X4 both onError epoch checks off', [(IC,) + PRE, (IC,) + POST], AUTH),
    ('X5 onRequest + post-refresh checks off', [(IC,) + ON_REQ, (IC,) + POST], AUTH),
    ('X6 all three epoch checks off', [(IC,) + ON_REQ, (IC,) + PRE, (IC,) + POST], AUTH),
    ('B1 FormData not cloned on replay', [(IC, '? (options.data as FormData).clone()', '? options.data')], AUTH),
    ('B2 Stream body guard removed', [(IC, '        options.data is Stream ||\n', '')], AUTH),
    ('T1 every refresh failure is a rejection', [(IC, '    _ => false,\n  };', '    _ => true,\n  };')], AUTH),
    ('T2 429 counts as rejection', [(IC, 'status != 408 && status != 429', 'status != 408')], AUTH),
    ('T3 ApiMalformed not a rejection', [(IC, 'ApiUnauthorized() || ApiMalformed() => true', 'ApiUnauthorized() => true')], AUTH),
    ('P1 refresh on 403 (old M3)', [(IC, 'if (err.response?.statusCode != 401 ||', 'if (!const [401, 403].contains(err.response?.statusCode) ||')], AUTH),
    ('P2 sign-out strip removed', [(IC, '        options.headers.remove(\'Authorization\');\n        options.extra[_applied] = false;\n', '')], AUTH),
    ('P3 replayed flag ignored (old M8)', [(IC, '        options.extra[_replayed] == true ||\n', '')], AUTH),
    ('S1 boot check back to directory listing', [(DI, '      nothingSaved = !store.existsSync(Session.defaultKey);', '      nothingSaved = !store.directory.existsSync() || store.directory.listSync().isEmpty;')], SESS + BOOT + TU),
    ('S2 boot always reads (no skip)', [(DI, '      nothingSaved = !store.existsSync(Session.defaultKey);', '      nothingSaved = store.directory.path.isEmpty;')], SESS + BOOT + TU),
    ('R1 repeat sign-in of the same user announces again', [(SS, 'final changed = _current?.userId != userId;', 'final changed = _current?.userId != userId || true;')], SESS),
    ('R2 a different user is not announced', [(SS, 'final changed = _current?.userId != userId;', 'final changed = _current == null;')], SESS),
    ('L1 save queue created eagerly', [(SS, '  Future<void>? _tail;', '  Future<void>? _tail = Future<void>.value();')], TU + SESS + BOOT),
    ('C1 McTestContainer without ApiAuthDIInitializer', [(TC, '    const ApiAuthDIInitializer(),\n', '')], TU),
    ('C2 McTestContainer without SessionDIInitializer and ApiAuth', [(TC, '    const SessionDIInitializer(),\n', ''), (TC, '    const ApiAuthDIInitializer(),\n', '')], TU),
]
only = sys.argv[1:]
for name, edits, targets in M:
    if only and name.split()[0] not in only:
        continue
    originals = {}
    for f, old, new in edits:
        p = REPO / f
        originals.setdefault(f, p.read_text())
        src = p.read_text()
        assert src.count(old) == 1, (name, f, src.count(old))
        p.write_text(src.replace(old, new))
    try:
        r = subprocess.run(['tool/bazelw', OB, 'test', '--nocache_test_results', *targets],
                           cwd=REPO, capture_output=True, text=True)
        out = (r.stdout + r.stderr).replace('\r', '\n')
        bad = re.findall(r'^(//\S+)\s+(FAILED|TIMEOUT) in (\S+)', out, re.M)
        builderr = [l for l in out.splitlines() if l.startswith('ERROR:')]
        if bad:
            print(f'KILLED   {name}: ' + ', '.join(f'{t} {k} {s}' for t, k, s in bad))
        elif builderr:
            print(f'BUILD-ERROR (not evidence) {name}: {builderr[:2]}')
        else:
            print(f'SURVIVED {name}')
        sys.stdout.flush()
    finally:
        for f, src in originals.items():
            (REPO / f).write_text(src)
