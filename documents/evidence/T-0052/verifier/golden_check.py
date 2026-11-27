import re
src = open('utility/mc_feature_flags/test/experiments_test.dart', encoding='utf8').read()
rows = re.findall(r"\('([^']*)', '([^']*)', (\d+), '(\w+)'\)", src.split('_golden = [')[1].split('];')[0])
EXP = {'store_home_layout': [('control', 5000), ('compact', 3000), ('rich', 2000)],
       'trivia_hint': [('control', 10000), ('hint', 0)],
       'checkout_cta': [('a', 1), ('b', 1), ('c', 1)],
       'é-exp': [('control', 50), ('b', 50)]}

def fnv(b):
    h = 2166136261
    for x in b:
        h = ((h ^ x) * 16777619) & 0xFFFFFFFF
    return h

bad = 0
for e, s, b, v in rows:
    bk = fnv(f'{e}:{s}'.encode()) % 10000
    tot = sum(w for _, w in EXP[e]); cum = 0; pick = EXP[e][0][0]
    for n, w in EXP[e]:
        cum += w
        if bk < cum * 10000 // tot:
            pick = n
            break
    ok = bk == int(b) and pick == v
    bad += not ok
    print('OK ' if ok else 'BAD', e, repr(s), bk, pick, b, v)
print(len(rows), 'rows', bad, 'bad')
