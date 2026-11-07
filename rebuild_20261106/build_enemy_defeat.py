from pathlib import Path
import sys,json,hashlib,shutil,re,struct
R=Path(__file__).resolve().parent;out=R/sys.argv[1];assert not out.exists();runtime=out/'runtime';shutil.copytree(R/'motion_combo14/runtime',runtime)
for folder in [R.parent/'combat_quality_review_20261107/changes']:
 for p in folder.rglob('*'):
  if p.is_file():d=runtime/p.relative_to(folder);d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,d)
sha=lambda b:hashlib.sha256(b).hexdigest()
m=runtime/'first_hero_full_admission_20261020/manifest.json';g=runtime/'release_generation_20261020/generation.gd';d=json.loads(m.read_text());d['files']={'res://'+p.relative_to(runtime).as_posix():sha(p.read_bytes()) for p in sorted(runtime.rglob('*')) if p.is_file() and p not in [m,g]};m.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');mh=sha(m.read_bytes());g.write_text(re.sub(r'const MANIFEST_SHA := "[a-f0-9]{64}"','const MANIFEST_SHA := "'+mh+'"',g.read_text()))
boot=out/'boot';boot.mkdir()
for n in ['boot.gd','boot.tscn','project.godot']:shutil.copyfile(R/'boot234'/n,boot/n)
data=bytearray();entries=[]
for p in sorted(runtime.rglob('*')):
 if not p.is_file():continue
 while len(data)%16:data.append(0)
 b=p.read_bytes();entries.append((p.relative_to(runtime).as_posix(),len(data),len(b),hashlib.md5(b).digest()));data.extend(b)
while len(data)%16:data.append(0)
header=struct.pack('<6IQQ',0x43504447,3,4,6,3,2,112,112+len(data))+bytes(72);di=bytearray(struct.pack('<I',len(entries)))
for n,o,s,h in entries:
 b=n.encode();b+=bytes((-len(b))%4);di.extend(struct.pack('<I',len(b))+b+struct.pack('<QQ',o,s)+h+struct.pack('<I',0))
pck=boot/'packs/runtime.pck';pck.parent.mkdir();pck.write_bytes(header+data+di)
d=json.loads((R/'boot234/release_template.json').read_text());d['packs'][0].update(path=str(pck.resolve()),sha256=sha(pck.read_bytes()));d['script_paths']=['res://'+n for n,_,_,_ in entries if n.endswith('.gd')];d['binding_manifest_sha256']=mh;d['resolved_manifests']={'res://first_hero_full_admission_20261020/manifest.json':mh};(boot/'descriptor.json').write_text(json.dumps(d,ensure_ascii=False,indent=2));print(out,sha(pck.read_bytes()))
