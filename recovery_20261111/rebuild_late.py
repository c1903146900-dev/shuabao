#!/usr/bin/env python3
"""Restore sealed late checkpoints from fixed public inputs. Never runs Godot/network.
Usage: python rebuild_late.py [--check-only] [--source SOURCE_ROOT]
Requires completed elixir_all_recovered01 and boot234 in SOURCE_ROOT/rebuild_20261106.
Outputs fresh checkpoint directories there; existing outputs are verified, not rewritten.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil, struct, subprocess, sys, tempfile

def sha(b): return hashlib.sha256(b).hexdigest()
def js(p): return json.loads(p.read_text())
STEPS=[
 ('immediate_recovered01','immediate_elixir_20261110',None,'d218ded00ff78fd279f4b585382f3dc910bf194ca0dbc00ef4bec1d5d7864c4e'),
 ('steel_undo_recovered01','steel_undo_20261110','steel_undo.patch','30fc86491e3b1b407016770f3040bd7f8be09237660d60220e3f563e8ed289e6'),
 ('exit_reopen02','exit_reopen_20261111','exit_reopen.patch','33a09806e3fe845aa5a3dbe620465c215be2b560e7984bbbf3cf41dcad9bfdf2'),
 ('p3_admit01','p3_admission_20261111',None,'a8c6825b8bf3f010899ee7f8f14f37753a7ca9116b20f1083c4f8b46b33f61b8'),
 ('p3_undo01','p3_undo_20261111','p3_undo.patch','e5e9e576a673a46bb58ada67c2b84f39b4be4062b637fbba054ac206c80b3d11'),
 ('body_shop01','body_shop_20261111','body_shop.patch','cdb50b61d1da8b51bd0aa4906cc4f7221d81c32c14b03871f6b9343503c59a6d'),
 ('equipment_hex01','equipment_hex_20261111','equipment_hex.patch','7cd9a60b9c6c51fde303c74f0a1064630670c9898687517cbaf5b20c3f1f9ad9'),
 ('g02_01','g02_equipment_20261111','g02.patch','fb8fff23eee8678af1f9c116dfe33f569b9b3f2c8a1aa9cd22c673bafae9b0d5'),
 ('regen01','regen_equipment_20261111','regen.patch','ea0e1041797c49221cda590c3838ba7e3e9b623d4c72e960a7f555383f610ca0'),
 ('held_hud01','held_hud_20261111','held_hud.patch','1c14d9b640e330ca73b973649c641acc23344e174db5509d95b6cc952b833c93'),
 ('aim_pitch01','aim_pitch_20261111','aim_pitch.patch','2b216c2971ea1beeb77ebbc73273f07e3290470dbd9a56191e60561cf2f6db89'),
 ('dash_trail01','dash_trail_20261111','dash_trail.patch','4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93'),
]
def pins(folder):
 p=folder/'SOURCE_HASHES.json'
 if not p.exists(): return []
 d=js(p)
 if isinstance(d,list):return d
 return [dict(v,path=k) for k,v in d.items()]
def verify_pins(runtime, pp, side):
 for h in pp:
  expected=h.get(side+'_sha256',h.get(side));p=runtime/h['path']
  assert (not p.exists()) if expected is None else p.is_file() and sha(p.read_bytes())==expected, (side,str(p),expected)
def binding_check(runtime):
 m=runtime/'first_hero_full_admission_20261020/manifest.json';g=runtime/'release_generation_20261020/generation.gd'
 d=js(m);actual={'res://'+p.relative_to(runtime).as_posix():sha(p.read_bytes()) for p in sorted(runtime.rglob('*')) if p.is_file() and p not in [m,g]}
 assert actual==d['files'],'binding mismatch'
 assert 'const MANIFEST_SHA := "'+sha(m.read_bytes())+'"' in g.read_text(),'generation mismatch'
 return len(actual)
def seal(out,R):
 runtime=out/'runtime';m=runtime/'first_hero_full_admission_20261020/manifest.json';g=runtime/'release_generation_20261020/generation.gd';d=js(m)
 d['files']={'res://'+p.relative_to(runtime).as_posix():sha(p.read_bytes()) for p in sorted(runtime.rglob('*')) if p.is_file() and p not in [m,g]}
 m.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');mh=sha(m.read_bytes())
 gs,n=re.subn(r'const MANIFEST_SHA := "[a-f0-9]{64}"','const MANIFEST_SHA := "'+mh+'"',g.read_text());assert n==1;g.write_text(gs)
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
 d=js(R/'boot234/release_template.json');d['packs'][0].update(path=str(pck.resolve()),sha256=sha(pck.read_bytes()));d['script_paths']=['res://'+n for n,_,_,_ in entries if n.endswith('.gd')];d['binding_manifest_sha256']=mh;d['resolved_manifests']={'res://first_hero_full_admission_20261020/manifest.json':mh};(boot/'descriptor.json').write_text(json.dumps(d,ensure_ascii=False,indent=2))
 return sha(pck.read_bytes())
def overlay(src,dest):
 for p in src.rglob('*'):
  if p.is_file():q=dest/p.relative_to(src);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--source',type=Path,default=Path(__file__).resolve().parent/'source');ap.add_argument('--check-only',action='store_true');a=ap.parse_args();S=a.source.resolve();R=S/'rebuild_20261106'
 # All downloaded selected public blobs must match the fixed git-tree manifest.
 for e in js(Path(__file__).resolve().parent/'SOURCE_GIT_BLOBS.json'):
  p=S/e['path'];assert p.is_file(),('missing download',str(p));b=p.read_bytes();assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==e['sha'],('git blob mismatch',str(p))
 for _,folder,patch,_ in STEPS:
  assert (S/folder).is_dir()
  if patch:assert (S/folder/patch).is_file()
 print('Public source manifest verified',flush=True)
 if a.check_only:return
 before=R/'elixir_all_recovered01';expected='79c6fa4a3c61b3a54b63e2db81087c1c8048493870ecbd3e678dfcc4ddd21dab'
 assert sha((before/'boot/packs/runtime.pck').read_bytes())==expected;binding_check(before/'runtime')
 for name,folder,patch,expected in STEPS:
  f=S/folder;pp=pins(f);verify_pins(before/'runtime',pp,'before');out=R/name
  if out.exists():
   assert sha((out/'boot/packs/runtime.pck').read_bytes())==expected,('existing output mismatch',name)
   verify_pins(out/'runtime',pp,'after');binding_check(out/'runtime');print(name,'existing verified',expected,flush=True);before=out;continue
  runtime=out/'runtime';shutil.copytree(before/'runtime',runtime)
  if patch:subprocess.run(['git','apply','--unidiff-zero',str(f/patch)],cwd=runtime,check=True)
  if name=='immediate_recovered01':
   for n,h in js(f/'FILE_HASHES.json').items():
    if n.startswith('changes/'):assert sha((f/n).read_bytes())==h
   overlay(f/'changes',runtime)
  with tempfile.TemporaryDirectory(prefix='late_overlay_') as tmp:
   gen=Path(tmp)/'generated';cmd=None
   if name=='p3_admit01':cmd=[str(f/'p3_prepare.py'),'--source',str(before/'runtime'),'--output',str(gen),'--report',str(Path(tmp)/'report.json')]
   if name=='body_shop01':cmd=[str(f/'body_reencode_portable.py'),str(before/'runtime'),str(f/'body_definition_v12.json'),str(gen)]
   if name=='g02_01':cmd=[str(f/'g02_reencode_portable.py'),str(before/'runtime'),str(f/'g02_definition.json'),str(runtime/'fengli_route_20261024/sim.gd'),str(gen)]
   if name=='regen01':cmd=[str(f/'regen_reencode_portable.py'),str(before/'runtime'),str(f/'regen_definition.json'),str(gen)]
   if cmd:subprocess.run([sys.executable]+cmd,check=True);overlay(gen,runtime)
  verify_pins(runtime,pp,'after');actual=seal(out,R);assert actual==expected,('pack mismatch',name,actual,expected)
  count=binding_check(runtime);print(name,actual,'bindings',count,flush=True);before=out
 print('DONE: aim_pitch01 accepted baseline and dash_trail01 isolated unvalidated candidate restored. No engine executed.',flush=True)
if __name__=='__main__':main()
