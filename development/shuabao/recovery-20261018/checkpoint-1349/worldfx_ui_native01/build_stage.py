from pathlib import Path
import json,hashlib,shutil,shlex
R=Path(__file__).resolve().parent;root=R.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def inventory(p):
 assert not any(x.is_symlink() for x in p.rglob('*'))
 return {x.relative_to(p).as_posix():sha(x) for x in p.rglob('*') if x.is_file()}
base=root/'p3_integrated_source01'; candidate=root/'worldfx_ui_candidate01'; fixture=root/'worldfx_ui_probe01'; cache=root/'resource_cache_validation01';g=root/'runtime_swapfix01'
assert sha(base/'SOURCE_PINS.json')=='b34d8236d9c0987714a0ed72db933da98af4bbc528d2fe2b8d5a548322438ff0'
bp=json.loads((base/'SOURCE_PINS.json').read_text());assert inventory(base/'source/game')==bp
assert sha(candidate/'SOURCE_PINS.expected.json')=='1286a70d07fda384d175eeecf538ca54fe9066242a9c42c90a85f5590e6ee67f'
assert sha(fixture/'FIXTURE_MANIFEST.json')=='f6435af10b4a1c18d5a723baaa011671613be27b5dd44eaf7940234e55740b3d'
source=R/'source/game';stage=R/'stage01';assert not source.exists() and not stage.exists()
shutil.copytree(base/'source/game',source)
for v in json.loads((candidate/'MANIFEST.json').read_text())['payload']:
 p=candidate/v['payload']; rel=v['target'].removeprefix('res://'); dst=source/rel
 assert sha(p)==v['sha256'] and p.stat().st_size==v['bytes']
 if v['action']=='replace': assert sha(dst)==v['preimage_sha256']
 else: assert not dst.exists()
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
expected=json.loads((candidate/'SOURCE_PINS.expected.json').read_text()); assert inventory(source)==expected and len(expected)==3046
shutil.copy2(candidate/'SOURCE_PINS.expected.json',R/'SOURCE_PINS.json');shutil.copytree(source,stage)
assert sha(cache/'USABLE_CACHE_MANIFEST.json')=='2458b5139ab11a4abb0de9cc4c24344acf2185720c2ff99c06379cc38b21b0aa'
for rel,v in json.loads((cache/'USABLE_CACHE_MANIFEST.json').read_text())['cache'].items():
 p=cache/'stage01'/rel; assert sha(p)==v['sha256'];dst=stage/rel;assert not dst.exists();dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst);expected[rel]=v['sha256']
fm=json.loads((fixture/'FIXTURE_MANIFEST.json').read_text())
for v in fm['fixture_files']:
 p=fixture/v['payload'];assert sha(p)==v['sha256'];rel=v['target'].removeprefix('res://');dst=stage/rel;assert not dst.exists();dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst);expected[rel]=v['sha256']
assert inventory(stage)==expected and len(expected)==3148
assert inventory(base/'source/game')==bp
(R/'STAGE_PINS_01.json').write_text(json.dumps(dict(sorted(expected.items())),indent=2)+'\n')
pre="from pathlib import Path; import hashlib,json; r=Path(%r); p=r/'SWAPFIX_PINS.json'; assert hashlib.sha256(p.read_bytes()).hexdigest()=='4801f5a92a65f26d629f7e1b920b4ceb932150a133e4f786aefefcc6a64954f5'; d=json.loads(p.read_text()); assert all(not (r/f).is_symlink() and (r/f).stat().st_size==v['bytes'] and hashlib.sha256((r/f).read_bytes()).hexdigest()==v['sha256'] for f,v in d['files'].items())"%str(g)
cmd=['python3','-I','-B',str(g/'owned_runtime_guard.py'),'--project',str(stage),'--out',str(R/'guard01'),'--pins',str(R/'STAGE_PINS_01.json'),'--pins-sha256',sha(R/'STAGE_PINS_01.json'),'--binary','/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64','--binary-sha256','f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3','--','--script',fm['entry'],'--','--worldfx-ui-evidence='+str(R/'evidence01')]
(R/'ROOT_COMMAND_01.txt').write_text('python3 -I -B -c '+shlex.quote(pre)+' && '+shlex.join(cmd)+'\n')
config={'source_pins_sha256':sha(R/'SOURCE_PINS.json'),'cache_manifest_sha256':sha(cache/'USABLE_CACHE_MANIFEST.json'),'fixture_manifest_sha256':sha(fixture/'FIXTURE_MANIFEST.json'),'stage_pins_sha256':sha(R/'STAGE_PINS_01.json'),'command_sha256':sha(R/'ROOT_COMMAND_01.txt'),'files':3148,'source_files':3046,'base_before_after_exact':True,'native_status':'NOT_RUN'}
(R/'STAGE_CONFIG_01.json').write_text(json.dumps(config,indent=2)+'\n');print(json.dumps(config))
