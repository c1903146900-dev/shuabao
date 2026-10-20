#!/usr/bin/env python3
"""Reconstruct this exact source performance comparison; never execute imported game code."""
import argparse, hashlib, json, pathlib, struct

def sha(data): return hashlib.sha256(data).hexdigest()
def safe(name):
 p=pathlib.PurePosixPath(name)
 if not name or p.is_absolute() or '..' in p.parts or '\\' in name or str(p)!=name:
  raise ValueError('unsafe resource path: '+name)
 return name

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--base-pck',type=pathlib.Path,required=True);ap.add_argument('--output',type=pathlib.Path,required=True);args=ap.parse_args()
 here=pathlib.Path(__file__).resolve().parent;m=json.loads((here/'MANIFEST.json').read_text());raw=args.base_pck.read_bytes()
 if len(raw)!=m['base_pck_bytes'] or sha(raw)!=m['base_pck_sha256']:raise ValueError('base PCK identity mismatch')
 if args.output.exists() or args.output.is_symlink():raise FileExistsError('output must not exist')
 if raw[:4]!=b'GDPC' or struct.unpack_from('<I',raw,4)[0]!=3:raise ValueError('expected Godot PCK v3')
 base=struct.unpack_from('<Q',raw,24)[0];directory=struct.unpack_from('<Q',raw,32)[0]
 if base!=112:raise ValueError('unexpected base offset')
 count=struct.unpack_from('<I',raw,directory)[0];pos=directory+4;files={}
 for _ in range(count):
  length=struct.unpack_from('<I',raw,pos)[0];pos+=4;name=safe(raw[pos:pos+length].rstrip(b'\0').decode('utf-8'));pos+=length
  off,size=struct.unpack_from('<QQ',raw,pos);pos+=16;md5=raw[pos:pos+16];pos+=16;flags=struct.unpack_from('<I',raw,pos)[0];pos+=4
  if flags or name in files or base+off+size>directory:raise ValueError('invalid PCK entry: '+name)
  data=raw[base+off:base+off+size]
  if len(data)!=size or hashlib.md5(data).digest()!=md5:raise ValueError('PCK checksum mismatch: '+name)
  files[name]=data
 if pos!=len(raw) or count!=3384:raise ValueError('unexpected PCK directory')
 seen=set()
 for row in m['files']:
  name=safe(row['path'])
  if name in seen:raise ValueError('duplicate delta path')
  seen.add(name);before=sha(files[name]) if name in files else None
  if before!=row['before']:raise ValueError('preimage mismatch: '+name)
  if 'replacement' in row:
   patch=row['replacement']; old=patch['old'].encode(); new=patch['new'].encode()
   if files[name].count(old)!=1:raise ValueError('replacement must match exactly once')
   data=files[name].replace(old,new)
  else:
   p=here/'payload'/name
   if p.is_symlink():raise ValueError('payload symlink')
   data=p.read_bytes()
  if sha(data)!=row['after']:raise ValueError('payload mismatch: '+name)
  files[name]=data
 if len(seen)!=10 or len(files)!=m['result_files']:raise ValueError('unexpected delta scope')
 # All identities are checked before creating the fresh output directory.
 args.output.mkdir(exist_ok=False);root=args.output/'source/game';root.mkdir(parents=True)
 pins={}
 for name,data in sorted(files.items()):
  p=root/name;p.parent.mkdir(parents=True,exist_ok=True)
  with p.open('xb') as f:f.write(data)
  pins[name]=sha(data)
 pack=args.output/'Shuabao.canonical.pck';rows=[]
 with pack.open('xb') as f:
  f.write(raw[:112])
  for name,data in sorted(files.items()):
   off=f.tell()-112;f.write(data);f.write(b'\0'*((-f.tell())%16));rows.append((name,off,len(data),hashlib.md5(data).digest()))
  directory=f.tell();f.write(struct.pack('<I',len(rows)))
  for name,off,size,md5 in rows:
   nb=name.encode();nb+=b'\0'*((-len(nb))%4);f.write(struct.pack('<I',len(nb)));f.write(nb);f.write(struct.pack('<QQ',off,size));f.write(md5);f.write(struct.pack('<I',0))
  f.seek(32);f.write(struct.pack('<Q',directory))
 if pack.stat().st_size!=m['result_pck_bytes'] or sha(pack.read_bytes())!=m['result_pck_sha256']:raise ValueError('final PCK identity mismatch; retain output for diagnosis')
 with (args.output/'SOURCE_PINS.json').open('x') as f:json.dump(pins,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'status':'EXACT_BYTES_RESTORED_NATIVE_UNRUN','files':len(files),'pck_sha256':m['result_pck_sha256']}))
if __name__=='__main__':main()
