from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
data=Path(sys.argv[2]).read_text(encoding='utf-8')
ids=set(map(int,re.findall(r"d\.AddPin\(\s*(\d+)",data)))
bad=[str(i) for i,l in enumerate(s.splitlines(),1) if "StringToName(" in l]
print("CHECK_KIND=LOCAL_API_AND_LITERAL_TAG_SOURCE_CHECK_NOT_ENGINE")
if bad:
 print("UNSUPPORTED_StringToName_LINES="+",".join(bad));sys.exit(1)
for func,prefix in [("GwmLocalShopActorTag","gwm_shop_actor_"),("GwmLocalMinimapTag","gwm_mini_")]:
 body=s.split("function "+func+"(",1)[1].split("\n}",1)[0]
 pairs=re.findall(r"case (\d+): return '([^']+)';",body)
 assert len(pairs)==len(ids)==91
 assert {int(n) for n,t in pairs}==ids
 assert all(t==prefix+n for n,t in pairs)
 print(func+"=91_UNIQUE_LITERAL_NAMES")
assert "GwmLocalShopActorTag( pins[ idx ].id )" in s
assert "GwmLocalMinimapTag( pins[ i ].id )" in s
print("UNSUPPORTED_CALLS=0")
