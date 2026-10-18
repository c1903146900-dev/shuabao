from pathlib import Path
import json,hashlib
P=Path(__file__).resolve().parents[1]; B=P.parent/'base/game'; O=Path(__file__).resolve().parent/'overlay'; NS='yan_p3_reimplementation_20261018b'; M=NS+'/migration.json'; G=NS+'/gate.gd'; SB='visual_rework_20261009/binding/source_binding.json'; LB='visual_rework_20261009/binding/live_binding.gd'; VB='visual_rework_20261009/binding/visual_binding.json'
def sha(x):return hashlib.sha256(x).hexdigest()
def js(x):return (json.dumps(x,ensure_ascii=False,indent=2)+'\n').encode()
def put(path,raw):
 f=O/path;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(raw)
old=json.loads((B/SB).read_bytes()); assert len(old['runtime_map'])==1747
vis=json.loads((B/VB).read_bytes());assert len(vis['runtime_map'])==71
pairs={
 'tests/ink_river_hexes_20261006/ordinary01/sim.gd':P/'integration02/sim.gd',
 'equipment_prism_20261011/model.gd':P/'integration02/model.gd',
 'tests/ink_rest_service_20261006/candidate01/rest_service.gd':P/'integration02/rest_service.gd',
 **{'tests/ink_river_hexes_20261006/ordinary01/'+f:P/'ui01'/f for f in ['catalog.gd','growth_hud.gd','runtime_text.gd']},
 'tests/ink_river_hexes_20261006/ordinary01/hud_projection.gd':P/'projection01/hud_projection.gd',
 'tests/ink_ordinary_visuals_20261007/candidate01/host.gd':P.parent/'ordinary_host_startup_fix01/payload/tests/ink_ordinary_visuals_20261007/candidate01/host.gd'}
live=(B/LB).read_text(); a=' for path:String in mapped:\n  if not _safe(path) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(mapped[path]):return _deny("runtime_source_changed:"+path)\n return {"accepted":true}'
assert a in live;live=live.replace(a,' return P3Gate.verify_legacy_map(mapped)')
live=live.replace('extends RefCounted','extends RefCounted\nconst P3Gate=preload("res://'+G+'")\nconst LEGACY_CANDIDATES='+json.dumps(old['runtime_candidates']),1)
live=live.replace('static func read_capabilities(sim:Node,include_source_adapter_hooks:bool=false)->Dictionary:\n','static func read_capabilities(sim:Node,include_source_adapter_hooks:bool=false)->Dictionary:\n var gameplay:Dictionary=P3Gate.verify()\n if not gameplay.accepted:return gameplay\n',1)
live=live.replace('item.get("runtime_candidates",[])!=Catalog.FIRST_SLICE_ALLOWED_CANDIDATES','item.get("runtime_candidates",[])!=LEGACY_CANDIDATES')
put(LB,live.encode());pairs[LB]=O/LB
changes={}
for rel,f in pairs.items():
 before=(B/rel).read_bytes();after=f.read_bytes();assert old['runtime_map']['res://'+rel]==sha(before)
 pre=NS+'/preimages/'+rel;put(pre,before);put(rel,after)
 changes['res://'+rel]={'before':sha(before),'after':sha(after),'preimage':'res://'+pre}
core=(P/'core01/p3_state.gd').read_bytes();put(NS+'/p3_state.gd',core)
prior=NS+'/predecessor_source_binding.json';put(prior,(B/SB).read_bytes())
manifest={'schema':'yan-p3-gameplay-migration-1','predecessor':'res://'+prior,'predecessor_sha':sha((B/SB).read_bytes()),'visual_path':'res://'+VB,'visual_sha':sha((B/VB).read_bytes()),'changes':changes,'added':{'res://'+NS+'/p3_state.gd':sha(core)},'runtime_candidates':old['runtime_candidates'][:8]+['P3']+old['runtime_candidates'][8:]}
mraw=js(manifest);put(M,mraw)
new=dict(old);new['p3_gameplay_migration']={'path':'res://'+M,'sha256':sha(mraw),'runtime_candidates':manifest['runtime_candidates']};put(SB,js(new))
gate='''extends RefCounted
# Real current gameplay afters and exact predecessor preimages are distinct gates.
const MANIFEST="res://@M@"
const MANIFEST_SHA="@MS@"
const SOURCE="res://@SB@"
const SOURCE_SHA="@SS@"
const SELF="res://@G@"
const SELF_SHA="@SELF@"
static func deny(reason:String)->Dictionary:return {"accepted":false,"reason":"p3_migration:"+reason}
static func read(path:String)->Variant:return JSON.parse_string(FileAccess.get_file_as_string(path))
static func verify()->Dictionary:
 var own:String=FileAccess.get_file_as_string(SELF).replace(SELF_SHA,"@SELF@")
 if own.sha256_text()!=SELF_SHA:return deny("gate_changed")
 if FileAccess.get_sha256(MANIFEST)!=MANIFEST_SHA or FileAccess.get_sha256(SOURCE)!=SOURCE_SHA:return deny("manifest_or_source_changed")
 var m:Variant=read(MANIFEST)
 if not m is Dictionary or m.schema!="yan-p3-gameplay-migration-1" or m.changes.size()!=9:return deny("schema_or_exact_changes")
 if FileAccess.get_sha256(m.predecessor)!=m.predecessor_sha or FileAccess.get_sha256(m.visual_path)!=m.visual_sha:return deny("predecessor_or_visual_changed")
 var prior:Dictionary=read(m.predecessor)
 var current:Dictionary=read(SOURCE)
 if prior.runtime_map.size()!=1747 or current.runtime_map!=prior.runtime_map:return deny("historical_map_changed")
 if current.p3_gameplay_migration.path!=MANIFEST or current.p3_gameplay_migration.sha256!=MANIFEST_SHA or current.p3_gameplay_migration.runtime_candidates!=m.runtime_candidates:return deny("capability_not_bound")
 for path:String in m.changes:
  var c:Dictionary=m.changes[path]
  if prior.runtime_map.get(path,"")!=c.before:return deny("wrong_predecessor:"+path)
  if FileAccess.get_sha256(c.preimage)!=c.before:return deny("preimage_changed:"+path)
  if FileAccess.get_sha256(path)!=c.after:return deny("current_after_changed:"+path)
 for path:String in m.added:
  if FileAccess.get_sha256(path)!=m.added[path]:return deny("added_resource_changed:"+path)
 return {"accepted":true}
static func verify_legacy_map(mapped:Dictionary)->Dictionary:
 var checked:Dictionary=verify()
 if not checked.accepted:return checked
 var m:Dictionary=read(MANIFEST)
 var prior:Dictionary=read(m.predecessor)
 var visual:Dictionary=read(m.visual_path)
 if visual.runtime_map.size()!=71:return deny("visual_map_size")
 if mapped!=prior.runtime_map and mapped!=visual.runtime_map:return deny("unauthorized_map")
 for path:String in mapped:
  var actual:String=path
  if m.changes.has(path):actual=m.changes[path].preimage
  if FileAccess.get_sha256(actual)!=str(mapped[path]):return deny("legacy_source_changed:"+path)
 return {"accepted":true}
'''
for a,b in {'@M@':M,'@MS@':sha(mraw),'@SB@':SB,'@SS@':sha(js(new)),'@G@':G}.items():gate=gate.replace(a,b)
# Both placeholder occurrences must normalize identically after replacing only constant.
normalized=gate; selfsha=sha(normalized.encode());gate=gate.replace('const SELF_SHA="@SELF@"','const SELF_SHA="'+selfsha+'"');put(G,gate.encode())
files={str(f.relative_to(O)):sha(f.read_bytes()) for f in sorted(O.rglob('*')) if f.is_file()}
(Path(__file__).parent/'OVERLAY_MANIFEST.json').write_bytes(js({'status':'WIP_MIGRATION_NOT_NATIVE_VERIFIED','files':files,'runtime_map':1747,'visual_map':71,'changed_originals':len(changes),'old_maps_preserved':True}))
print('overlay files',len(files),'manifest',sha((Path(__file__).parent/'OVERLAY_MANIFEST.json').read_bytes()))
