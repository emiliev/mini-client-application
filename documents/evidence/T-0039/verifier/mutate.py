# T-0039 Verifier mutation runner. Applies one mutation at a time in the
# verifier worktree, runs the original test targets, restores the file.
import pathlib
import subprocess
import sys

REPO = pathlib.Path('/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a6e11cab586c62c97')
OB = '--output_base=/tmp/mc-ob-T-0039-verifier'
AUTH = ['//utility/mc_api_auth:auth_interceptor_test', '//utility/mc_api_auth:auth_api_test']
SESS = ['//utility/mc_session:session_test', '//utility/mc_session:session_di_test']
FIX = ['//utility/mc_fixtures_identity:identity_test', '//utility/mc_fixtures_identity:provider_contract_test']
BOOT = ['//app/wiring/app_core:boot_test']
IC = 'utility/mc_api_auth/lib/src/auth_interceptor.dart'
SS = 'utility/mc_session/lib/src/session.dart'
DI = 'utility/mc_session/lib/src/session_di_initializer.dart'
IH = 'utility/mc_fixtures_identity/lib/src/handlers/identity_handlers.dart'
M = [
    ('M1 shared-refresh latch removed', IC, 'await (_refreshing ??= _refresh())', 'await _refresh()', AUTH),
    ('M2 replay keeps the old token (header not replaced on replay)', IC,
     "(ours || !options.headers.containsKey('Authorization'))",
     "!options.headers.containsKey('Authorization')", AUTH),
    ('M3 refresh also on 403', IC, 'if (err.response?.statusCode != 401 ||',
     'if (!const [401, 403].contains(err.response?.statusCode) ||', AUTH),
    ('M4 failed refresh does not clear the session', IC,
     '          await _writer.signOut();\n          return const _SignedOut();',
     '          return const _SignedOut();', AUTH),
    ('M5 updateTokens revives a signed-out session', SS,
     '    final current = _current;\n    if (current == null) {\n      return Future.value(success(null));\n    }\n    final active = _Active(current.userId, tokens);',
     "    final current = _current;\n    final active = _Active(current?.userId ?? 'revived', tokens);",
     SESS + AUTH),
    ('M6 Session saves not serialised (FileStore still serialises per key)', SS,
     'final run = _tail.then((_) => action());', 'final run = action();', SESS),
    ('M7 _refreshing never cleared', IC, '      _refreshing = null;\n', '', AUTH),
    ('M8 replay flag ignored', IC, '        options.extra[_replayed] == true ||\n', '', AUTH),
    ('M9 token counter does not skip revoked numbers', IH,
     '} while (_revoked(context).contains(mintRefreshToken(userId, n)));',
     '} while (n < 0 && _revoked(context).contains(mintRefreshToken(userId, n)));', FIX + AUTH),
    ('M10 offline refresh signs out', IC, 'if (failure is ApiOffline ||', 'if (failure is ApiNotFound ||', AUTH),
    ('M11 boot never restores (always Session.empty)', DI, 'final session = nothingSaved',
     'final session = nothingSaved || true', SESS + BOOT),
    ('M12 bearer prefix dropped', IC, "static const _prefix = 'Bearer ';", "static const _prefix = '';", AUTH),
    ('M13 sign-out does not delete the store', SS, 'return _enqueue(() => _store.delete(_key));',
     'return Future.value(success(null));', SESS + AUTH),
]
only = sys.argv[1:]
for name, f, old, new, targets in M:
    if only and name.split()[0] not in only:
        continue
    p = REPO / f
    src = p.read_text()
    assert src.count(old) == 1, (name, src.count(old))
    p.write_text(src.replace(old, new))
    try:
        r = subprocess.run(['tool/bazelw', OB, 'test', '--nocache_test_results', *targets],
                           cwd=REPO, capture_output=True, text=True)
        out = (r.stdout + r.stderr).replace('\r', '\n')
        failed = [l.split()[0] for l in out.splitlines() if ' FAILED in ' in l]
        builderr = [l for l in out.splitlines() if l.startswith('ERROR:')]
        if failed:
            print(f'KILLED   {name}: {failed}')
        elif builderr:
            print(f'BUILD-ERROR (not evidence) {name}: {builderr[:2]}')
        else:
            print(f'SURVIVED {name}')
        sys.stdout.flush()
    finally:
        p.write_text(src)
