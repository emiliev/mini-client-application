# T-0039 Verifier: run my probes against single mutations (negative controls).
import pathlib
import re
import subprocess

REPO = pathlib.Path('/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a6e11cab586c62c97')
OB = '--output_base=/tmp/mc-ob-T-0039-verifier'
IC = 'utility/mc_api_auth/lib/src/auth_interceptor.dart'
DI = 'utility/mc_session/lib/src/session_di_initializer.dart'
PROBE = '//utility/mc_api_auth:verifier_probe_test'
BOOT = '//utility/mc_session:verifier_boot_probe_test'
C = [
    ('E3 one shared refresh across epochs', IC, 'if (current != null && current.epoch == epoch) {', 'if (current != null) {', PROBE),
    ('X3 onError post-refresh epoch check off', IC, '      if (epoch != _reader.epoch) {\n        // Signed out', '      if (epoch < 0) {\n        // Signed out', PROBE),
    ('X4 both onError epoch checks off', IC, None, None, PROBE),
    ('S1 boot check back to directory listing', DI, '      nothingSaved = !store.existsSync(Session.defaultKey);',
     '      nothingSaved = !store.directory.existsSync() || store.directory.listSync().isEmpty;', BOOT),
]
PRE = ('        epoch is! int ||\n        epoch != _reader.epoch) {', '        epoch is! int) {')
POST = ('      if (epoch != _reader.epoch) {\n        // Signed out', '      if (epoch < 0) {\n        // Signed out')
for name, f, old, new, target in C:
    p = REPO / f
    src = p.read_text()
    edits = [PRE, POST] if old is None else [(old, new)]
    s = src
    for o, n in edits:
        assert s.count(o) == 1, name
        s = s.replace(o, n)
    p.write_text(s)
    try:
        r = subprocess.run(['tool/bazelw', OB, 'test', '--nocache_test_results', '--test_output=all', target],
                           cwd=REPO, capture_output=True, text=True)
        out = (r.stdout + r.stderr).replace('\r', '\n')
        failed = sorted(set(re.findall(r'\+\d+ -\d+: (.*?) \[E\]', out)))
        print(f'{name}: ' + ('; '.join(failed) if failed else 'no probe failed'))
    finally:
        p.write_text(src)
