from pathlib import Path
import hashlib,json,copy
P=Path(__file__).resolve().parent;O=P/'overlay';B=P.parents[1]/'base';NS='yan_p3_reimplementation_20261018b/';sha=lambda b:hashlib.sha256(b).hexdigest();load=lambda r:json.loads((O/r).read_bytes())
inv=json.loads((B/'PUBLIC_SOURCE_MANIFEST.json').read_text()); hashes={'res://'+x['path'].removeprefix('game/'):x['sha256'] for x in inv['files']}
manifest=load('yan_p3_reimplementation_20261018b/migration.json');prior=load(NS+'predecessor_source_binding.json');source=load('visual_rework_20261009/binding/source_binding.json');visual=json.loads((B/'game/visual_rework_20261009/binding/visual_binding.json').read_text())
for f in O.rglob('*'):
 if f.is_file():hashes['res://'+str(f.relative_to(O))]=sha(f.read_bytes())
assert len(prior['runtime_map'])==1747 and len(visual['runtime_map'])==71
assert source['runtime_map']==prior['runtime_map']
gate=(O/(NS+'gate.gd')).read_text();selfhash=gate.split('const SELF_SHA="')[1].split('"')[0];assert sha(gate.replace(selfhash,'@SELF@').encode())==selfhash
checks=[]
def verify(m,h,mapped):
 if mapped not in (prior['runtime_map'],visual['runtime_map']):return 'unauthorized_map'
 for path,c in m['changes'].items():
  if prior['runtime_map'].get(path)!=c['before']:return 'wrong_predecessor'
  if h.get(c['preimage'])!=c['before']:return 'preimage_changed'
  if h.get(path)!=c['after']:return 'current_after_changed'
 for path,want in m['added'].items():
  if h.get(path)!=want:return 'added_resource_changed'
 for path,want in mapped.items():
  actual=m['changes'].get(path,{}).get('preimage',path)
  if h.get(actual)!=want:return 'legacy_source_changed'
 return 'accepted'
for name,mapped in [('runtime',prior['runtime_map']),('visual',visual['runtime_map'])]:
 assert verify(manifest,hashes,mapped)=='accepted';checks.append(name+'_1747_or_71_replayed')
for path,c in manifest['changes'].items():
 for target,reason in [(path,'current_after_changed'),(c['preimage'],'preimage_changed')]:
  h=dict(hashes);h[target]='0'*64;actual=verify(manifest,h,prior['runtime_map']);assert actual==reason,(target,actual);checks.append(reason+':'+target)
 m=copy.deepcopy(manifest);m['changes'][path]['before']='0'*64
 assert verify(m,hashes,prior['runtime_map'])=='wrong_predecessor';checks.append('wrong_predecessor:'+path)
h=dict(hashes);h[next(iter(manifest['added']))]='0'*64;assert verify(manifest,h,prior['runtime_map'])=='added_resource_changed';checks.append('core_rejected')
mapped=dict(prior['runtime_map']);mapped['res://bogus']='0'*64;assert verify(manifest,hashes,mapped)=='unauthorized_map';checks.append('unauthorized_map_rejected')
for path in visual['runtime_map']:
 if path not in manifest['changes']:
  h=dict(hashes);h[path]='0'*64;assert verify(manifest,h,visual['runtime_map'])=='legacy_source_changed';checks.append('visual_resource_rejected');break
checks.append('gate_self_seal_normalized')
out={'status':'PYTHON_MEMORY_REPLAY_PASS_NOT_GODOT','checks':len(checks),'details':checks,'limits':['Base hashes come from the freshly fully verified 3031 manifest; no duplicate large source hash pass','No actual GDScript execution or UI clicking','Historical test runners are preserved but not rerun']}
(P/'CHECK_RESULT.json').write_text(json.dumps(out,indent=2)+'\n');print(out['status'],len(checks))
