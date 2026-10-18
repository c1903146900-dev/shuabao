"""Create a fresh sealed source; preserve the recovered base exactly."""
from pathlib import Path
import hashlib,json,shutil
R=Path(__file__).resolve().parent;root=R.parent;base=root/'base/game';candidate=root/'p3_reimplementation/migration01';out=R/'source/game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def tree(p):
 assert not p.is_symlink()
 d={}
 for q in p.rglob('*'):
  assert not q.is_symlink(),q
  if q.is_file():d[q.relative_to(p).as_posix()]=sha(q)
 return d
assert sha(candidate/'OVERLAY_MANIFEST.json')=='ec79bef7eb9384b7431393e6045de0e093916acad3aa0af647e46f7f9f64ff63'
assert sha(root/'base/PUBLIC_SOURCE_MANIFEST.json')=='d24cf18fbcef701a55202a3d36fa6b4c4d0a7bbd900792e46bb0693cf682ec1a'
original={x['path'][5:]:x['sha256']for x in json.loads((root/'base/PUBLIC_SOURCE_MANIFEST.json').read_text())['files']};assert len(original)==3031 and tree(base)==original
m=json.loads((candidate/'OVERLAY_MANIFEST.json').read_text())['files'];assert len(m)==23 and tree(candidate/'overlay')==m
changed=set(m)&set(original);new=set(m)-set(original);assert len(changed)==10 and len(new)==13
assert not out.exists();shutil.copytree(base,out)
for rel,h in m.items():p=out/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(candidate/'overlay'/rel,p)
expected=original|m;assert len(expected)==3044 and tree(out)==expected and tree(base)==original
(R/'SOURCE_PINS.json').write_text(json.dumps(dict(sorted(expected.items())),indent=2)+'\n')
report={'status':'ASSEMBLED_STATIC_NOT_NATIVE','source_files':3044,'source_bytes':sum(p.stat().st_size for p in out.rglob('*')if p.is_file()),'changed_existing':sorted(changed),'new_files':sorted(new),'base_before_after_exact':True,'source_pins_sha256':sha(R/'SOURCE_PINS.json'),'overlay_manifest_sha256':sha(candidate/'OVERLAY_MANIFEST.json')}
(R/'ASSEMBLY_REPORT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
