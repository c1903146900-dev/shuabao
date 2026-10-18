"""Reassemble verified public parts and restore only the 98 sealed cache files.
Usage: python3 -I -B restore_cache.py FRESH_OUTPUT_DIRECTORY
No downloaded programs are executed. Original project/source sidecars are absent.
"""
from pathlib import Path,PurePosixPath
import hashlib,json,sys,tarfile,tempfile
HERE=Path(__file__).resolve().parent
PARTS_SHA='968072e3089aadae776f51cdbf9678833c179c739690c68c9ee1d1164f0c1a93'
def digest(b):return hashlib.sha256(b).hexdigest()
def require(ok,msg):
 if not ok:raise RuntimeError(msg)
def main():
 require(len(sys.argv)==2,'fresh output argument required');out=Path(sys.argv[1]).absolute();require(not out.exists(),'output already exists')
 mb=(HERE/'PARTS.json').read_bytes();require(digest(mb)==PARTS_SHA,'parts manifest changed');m=json.loads(mb)
 with tempfile.TemporaryFile()as archive:
  h=hashlib.sha256();total=0
  for index,p in enumerate(m['parts']):
   require(p['file']=='part-%03d.bin'%index,'unexpected part name');f=HERE/p['file'];require(not f.is_symlink(),'symlink part');b=f.read_bytes();require(len(b)==p['bytes']and digest(b)==p['sha256'],'part changed');archive.write(b);h.update(b);total+=len(b)
  require(total==m['archive_bytes']and h.hexdigest()==m['archive_sha256'],'archive mismatch');archive.seek(0)
  with tarfile.open(fileobj=archive,mode='r:xz')as tar:
   members=tar.getmembers();require(len(members)==99,'member count');names=[x.name for x in members];require(len(set(names))==99,'duplicate paths')
   for x in members:
    p=PurePosixPath(x.name);require(x.isfile()and not p.is_absolute()and '..'not in p.parts,'unsafe archive member')
   manifest=tar.extractfile('USABLE_CACHE_MANIFEST.json').read();require(digest(manifest)==m['cache_manifest_sha256'],'cache manifest changed');cache=json.loads(manifest)['cache'];require(len(cache)==98 and set(names)==set(cache)|{'USABLE_CACHE_MANIFEST.json'},'cache set mismatch')
   for rel,v in cache.items():
    require(rel.startswith('.godot/imported/'),'non-cache path');b=tar.extractfile(rel).read();require(len(b)==v['bytes']and digest(b)==v['sha256'],'cache hash mismatch')
   out.mkdir(parents=True)
   for rel in names:
    dest=out/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(tar.extractfile(rel).read())
 print(json.dumps({'restored_cache_files':98,'archive_sha256':m['archive_sha256'],'source_files_modified':False}))
if __name__=='__main__':main()
