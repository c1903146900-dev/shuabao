"""Fetch verified core files and literal GDScript dependencies ahead of bulk restore."""
from pathlib import Path
import importlib.util,json,urllib.parse,os,re
spec=importlib.util.spec_from_file_location('restore_base',Path(__file__).with_name('restore_base.py'));b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
m=json.loads((b.ROOT/'PUBLIC_SOURCE_MANIFEST.json').read_text());records={x['path']:x for x in m['files']}
queue=['game/data/final_design/catalog.gd','game/data/final_design/catalog.json','game/data/final_design/effective_overrides.json','game/tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd','game/equipment_prism_20261011/model.gd','game/tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd','game/tests/ink_river_hexes_20261006/ordinary01/sim.gd'];done={}
while queue:
 rel=queue.pop(0)
 if rel in done or rel not in records:continue
 f=records[rel];dest=b.ROOT/rel;data=dest.read_bytes()if dest.exists()else b.download(b.URL+urllib.parse.quote(rel,safe='/'))
 assert b.digest(data)==f['sha256']and b.blob(data)==f['git_blob_sha1']and len(data)==f['bytes']
 if not dest.exists():
  dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_name(dest.name+'.priority-part');tmp.write_bytes(data);os.replace(tmp,dest)
 done[rel]=f;print(rel,flush=True)
 (b.ROOT/'PRIORITY_VERIFIED.json').write_text(json.dumps(done,indent=2)+'\n')
 if rel.endswith('.gd'):
  for dep in re.findall(r'[\"\']res://([^\"\']+)[\"\']',data.decode()):
   if dep.endswith(('.gd','.json')):queue.append('game/'+dep)
print('priority closure',len(done),flush=True)
