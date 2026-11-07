"""Static consistency checks only. Never launches Godot or proves runtime behavior."""
from pathlib import Path
import argparse, hashlib, json, re
p=argparse.ArgumentParser();p.add_argument('--numeric-source',type=Path);a=p.parse_args()
r=Path(__file__).resolve().parent;overlay=r/'combined_changes01';base=r.parent/'rebuild_20261106/elixir_flow_draft03/runtime'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((r/'combined_manifest01.json').read_text())
assert {x.relative_to(overlay).as_posix() for x in overlay.rglob('*') if x.is_file()}==set(manifest)
for path,digest in manifest.items():assert sha(overlay/path)==digest,path
for path in ['fengli_route_20261024/sim.gd','fengli_route_20261024/binding.gd','tests/equipment_shop_transactions_20261004/shop_visit_model.gd']:
 assert not (overlay/path).exists(),path
for file in overlay.rglob('*.gd'):
 text=file.read_text();names=re.findall(r'^func (\w+)\(',text,re.M);assert len(names)==len(set(names)),file
 for target in re.findall(r'preload\("res://([^\"]+)"\)',text):assert (overlay/target).is_file() or (base/target).is_file(),(file,target)
consumer=(overlay/'fengli_route_20261024/elixir_consumer.gd').read_text()
assert 'const ITEMS=["elixir:01","elixir:02","elixir:03","elixir:04","elixir:05"]' in consumer
count=0
for gd,j in [('elixir_consumer.gd','elixir_values.json'),('steel_runtime.gd','steel_values.json')]:
 text=(overlay/'fengli_route_20261024'/gd).read_text();values=overlay/'fengli_route_20261024'/j
 assert sha(values)==re.search(r'VALUES_SHA256="([a-f0-9]+)"',text)[1]
 params=json.loads(values.read_text())['parameters']
 if a.numeric_source:
  source=json.loads(a.numeric_source.read_text())['parameters']
  for key,value in params.items():
   if not key.startswith('elixir:'):continue
   assert value=={k:source[key][k] for k in ['value','unit']},key;count+=1
assert 'steel.clear_paths()' in consumer and '_arcane_casts.clear()' in consumer
assert 'bool(model.state.get("actor_dead",false))' in consumer
assert 'state.shop_bool' not in consumer
print(json.dumps({'static_manifest_files':len(manifest),'numeric_source_values_checked':count,'static_consistency_passed':True,'engine_run':False,'parser_run':False,'runtime_acceptance':False},indent=2))
