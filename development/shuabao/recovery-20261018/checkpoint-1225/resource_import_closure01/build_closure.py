"""Build a fresh, non-executable asset-only import project from the verified base."""
from pathlib import Path,PurePosixPath
import json,hashlib,re,struct,shutil
R=Path(__file__).resolve().parent;BASE=R.parent/'base/game'
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=(BASE.parent/'PUBLIC_SOURCE_MANIFEST.json').read_bytes()
assert sha(manifest)=='d24cf18fbcef701a55202a3d36fa6b4c4d0a7bbd900792e46bb0693cf682ec1a'
records={x['path'][5:]:x for x in json.loads(manifest)['files']}
def verified(rel):
 p=BASE/rel;assert not p.is_symlink();b=p.read_bytes();f=records[rel]
 assert len(b)==f['bytes']and sha(b)==f['sha256']and hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==f['git_blob_sha1'],rel
 return b
def respath(s):
 assert s.startswith('res://');rel=s[6:];p=PurePosixPath(rel);assert not p.is_absolute()and '..'not in p.parts;return rel
missing=[];converted=[];files={}
for rel in sorted(k for k in records if k.endswith('.import')):
 b=verified(rel);t=b.decode();match=re.search(r'^path="([^"]+)"',t,re.M);assert match,rel;target=respath(match[1]);src=re.search(r'^source_file="([^"]+)"',t,re.M);assert src,rel;origin=respath(src[1]);assert origin+'.import'==rel
 row={'source':origin,'descriptor':rel,'target':target,'descriptor_sha256':sha(b)}
 if (BASE/target).is_file():
  row['existing_target_sha256']=sha(verified(target));converted.append(row);continue
 assert target.startswith('.godot/imported/'),target
 raw=verified(origin);row.update({'source_sha256':sha(raw),'source_bytes':len(raw)})
 params=t.split('[params]',1)[1];assert not re.search(r'res://',params),rel
 ext=Path(origin).suffix.lower()
 if ext=='.glb':
  magic,version,size=struct.unpack_from('<4sII',raw);assert magic==b'glTF'and version==2 and size==len(raw)
  n,kind=struct.unpack_from('<I4s',raw,12);assert kind==b'JSON';g=json.loads(raw[20:20+n]);uris=[x.get('uri','')for key in ('buffers','images')for x in g.get(key,[])];assert all(not u or u.startswith('data:')for u in uris),origin;row['glb_external_uri_count']=0
 if ext=='.svg':assert not re.search(r'(?:href\s*=|url\s*\()',raw.decode(),re.I),origin
 files[origin]=raw;files[rel]=b;missing.append(row)
assert len(missing)==98 and len(converted)==82 and len(files)==196
project=b'; Independent resource import closure. No scripts, scenes or autoloads.\nconfig_version=5\n\n[application]\nconfig/name="Recovery Resource Import Closure"\n\n[display]\nwindow/size/viewport_width=640\nwindow/size/viewport_height=360\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n'
files['project.godot']=project
for tree in ('source','stage01'):
 out=R/tree;assert not out.exists(),out;out.mkdir()
 for rel,b in files.items():p=out/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 actual={p.relative_to(out).as_posix():sha(p.read_bytes())for p in out.rglob('*')if p.is_file()};assert actual=={k:sha(v)for k,v in files.items()}
pins={k:sha(files[k])for k in sorted(files)}
(R/'STAGE_PINS_01.json').write_text(json.dumps(pins,indent=2)+'\n')
(R/'RESOURCE_CLASSIFICATION.json').write_text(json.dumps({'base_commit':'708454b99a631adac381417f820aabe6798c148c','base_manifest_sha256':sha(manifest),'missing_count':98,'converted_count':82,'missing':missing,'converted_excluded':converted,'closure_files':197,'closure_bytes':sum(map(len,files.values())),'native_status':'NOT_RUN','existing_sidecar_changes_must_fail':True,'source_paths_preserved':True},indent=2)+'\n')
(R/'PREPARATION_PINS.json').write_text(json.dumps({n:{'sha256':sha((R/n).read_bytes()),'bytes':(R/n).stat().st_size}for n in ['build_closure.py','STAGE_PINS_01.json','RESOURCE_CLASSIFICATION.json']},indent=2)+'\n')
print(json.dumps({'files':197,'bytes':sum(map(len,files.values())),'stage_pins_sha256':sha((R/'STAGE_PINS_01.json').read_bytes()),'preparation_pins_sha256':sha((R/'PREPARATION_PINS.json').read_bytes())}))
