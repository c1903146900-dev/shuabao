"""Restore only fixed public candidate43 source; never execute downloaded code."""
from pathlib import Path,PurePosixPath
import json,hashlib,urllib.request,concurrent.futures,time,os
ROOT=Path(__file__).resolve().parent/'base'
COMMIT='708454b99a631adac381417f820aabe6798c148c'
URL='https://raw.githubusercontent.com/c1903146900-dev/shuabao/'+COMMIT+'/development/shuabao/candidate43-rebuild/'
MANIFEST_BLOB='fcccf176ab0e04fad23c69136c45cd9bb5654bb8'
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def digest(b):return hashlib.sha256(b).hexdigest()
def download(url):
 for n in range(4):
  try:return urllib.request.urlopen(url,timeout=60).read()
  except Exception:
   if n==3:raise
   time.sleep(n+1)
def main():
 ROOT.mkdir(parents=True,exist_ok=True)
 mp=ROOT/'PUBLIC_SOURCE_MANIFEST.json';mb=mp.read_bytes() if mp.exists() else download(URL+mp.name)
 assert blob(mb)==MANIFEST_BLOB,'manifest Git blob mismatch'
 if not mp.exists():mp.write_bytes(mb)
 m=json.loads(mb);assert m['source_files']==3031 and m['source_bytes']==216204684
 records=m['files'];assert len(records)==3031
 paths=set()
 for f in records:
  p=PurePosixPath(f['path']);assert not p.is_absolute() and '..' not in p.parts and p.parts[0]=='game'
  assert f['path'] not in paths;paths.add(f['path'])
 def one(f):
  dest=ROOT/f['path'];assert not dest.is_symlink()
  b=dest.read_bytes() if dest.exists() else download(URL+urllib.parse.quote(f['path'],safe='/'))
  assert len(b)==f['bytes'] and digest(b)==f['sha256'] and blob(b)==f['git_blob_sha1'],f['path']
  if not dest.exists():
   dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_name(dest.name+'.recovery-part');tmp.write_bytes(b);os.replace(tmp,dest)
  return len(b)
 with concurrent.futures.ThreadPoolExecutor(max_workers=12)as pool:
  total=0
  for i,n in enumerate(pool.map(one,records),1):
   total+=n
   if i%100==0:print(json.dumps({'verified_files':i,'bytes':total}),flush=True)
 actual={p.relative_to(ROOT).as_posix()for p in (ROOT/'game').rglob('*')if p.is_file()};assert actual==paths and total==216204684
 report={'status':'RESTORED_SOURCE_BYTES_ONLY_NOT_RUNTIME_PASS','commit':COMMIT,'source_files':3031,'source_bytes':total,'manifest_git_blob_sha1':MANIFEST_BLOB,'manifest_sha256':digest(mb),'pathset_exact':True,'all_sha256_and_git_blob_sha1_verified':True,'historical_runtime_pass_inherited':False}
 (ROOT/'RECOVERY_VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
if __name__=='__main__':main()
