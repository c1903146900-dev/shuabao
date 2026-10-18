from pathlib import Path,PurePosixPath
import json,hashlib,urllib.request,urllib.parse,concurrent.futures
R=Path(__file__).resolve().parent
BASE='https://raw.githubusercontent.com/c1903146900-dev/shuabao/'
jobs=[]
def add(commit,remote,local,h,size=None):
 p=PurePosixPath(local)
 if p.is_absolute() or '..' in p.parts:raise ValueError(local)
 jobs.append((BASE+commit+'/development/shuabao/recovery-20261018/'+urllib.parse.quote(remote,safe='/'),R/local,h,size))
m=json.loads((R/'migration01/OVERLAY_MANIFEST.json').read_text())
for rel,h in m['files'].items():add('64832e8dba5e51e6e202fb72bf1804321c6671dd','checkpoint-1227/p3_reimplementation/migration01/overlay/'+rel,'migration01/overlay/'+rel,h)
for directory,seal in [('runtime_spawnfix01','SPAWNFIX_PINS.json'),('runtime_tinyguard01','TINYGUARD_PINS.json')]:
 for rel,v in json.loads((R/directory/seal).read_text())['files'].items():add('a4beb870cd4379baa14faecbb1eb70e8dce019a2','checkpoint-1340/'+directory+'/'+rel,directory+'/'+rel,v['sha256'],v['bytes'])
for v in json.loads((R/'cache_parts01/PARTS.json').read_text())['parts']:add('34f29ebd330b79747da39a953c978a042accda31','checkpoint-cache1242/resource_cache_validation01/cache_parts01/'+v['file'],'cache_parts01/'+v['file'],v['sha256'],v['bytes'])
def one(job):
 url,p,h,size=job
 if p.is_symlink():raise ValueError('symlink')
 b=p.read_bytes() if p.exists() else urllib.request.urlopen(url,timeout=90).read()
 if hashlib.sha256(b).hexdigest()!=h or (size is not None and len(b)!=size):raise ValueError('hash:'+str(p))
 if not p.exists():p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 return str(p.relative_to(R))
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for result in pool.map(one,jobs):print(result,flush=True)
print('VERIFIED_FILES',len(jobs),flush=True)
