"""python3 tools/set_race_info.py <race> <Title> <text file>: puts Ari's database text into RACE_INFO."""
import re, sys
race, title, path = sys.argv[1:4]
P = '/root/eb/scripts/campaign.gd'
s = open(P).read()
txt = open(path).read().strip()
esc = txt.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
new = '\t"%s": ["%s", "%s"],' % (race, title, esc)
s2, n = re.subn(r'\t"%s": \["[^"]*", "(?:[^"\\]|\\.)*"\],' % re.escape(race), lambda m: new, s, count=1)
assert n == 1, race
open(P, 'w').write(s2)
print("ok", race)
