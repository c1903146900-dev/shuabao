"""Restore the nine exact baked meshes; no engine or authoring code executes."""
import argparse,base64,hashlib,json,pathlib,re,zlib

def sha(data): return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();root=pathlib.Path(__file__).resolve().parent
 if a.output.exists() or a.output.is_symlink(): raise ValueError('output must not exist')
 m=json.loads((root/'MANIFEST.json').read_text());names=[f'mesh_{i:02d}.res' for i in range(9)]
 if m['schema']!='cloth02-exact-binary-text-archive-1' or [r['name'] for r in m['files']]!=names: raise ValueError('exact nine-file scope required')
 if m['total_bytes_limit']!=2097152 or not 0<m['total_bytes']<=2097152: raise ValueError('invalid size cap')
 if sha((root/'BAKE_MANIFEST.json').read_bytes())!=m['bake_manifest_sha256']: raise ValueError('bake manifest changed')
 decoded={};seen=set();total=0
 for i,row in enumerate(m['files']):
  if not 0<row['bytes']<=2097152: raise ValueError('invalid file size')
  pieces=[]
  for n,chunk in enumerate(row['chunks']):
   path=chunk['path'];expected=f'chunks/mesh_{i:02d}_{n:02d}.txt'
   if path!=expected or path in seen: raise ValueError('unsafe or repeated chunk')
   seen.add(path);file=root/path
   if file.is_symlink() or file.parent.is_symlink(): raise ValueError('symlink chunk denied')
   data=file.read_bytes()
   if len(data)>49152 or len(data)!=chunk['bytes'] or sha(data)!=chunk['sha256']: raise ValueError('chunk mismatch')
   pieces.append(data)
  compressed=base64.b64decode(b''.join(pieces),validate=True);dec=zlib.decompressobj();data=dec.decompress(compressed,row['bytes']+1)
  if len(data)!=row['bytes'] or not dec.eof or dec.unused_data or dec.unconsumed_tail or sha(data)!=row['sha256']: raise ValueError('decoded bytes mismatch')
  total+=len(data)
  if total>2097152: raise ValueError('total limit')
  decoded[row['name']]=data
 if total!=m['total_bytes']: raise ValueError('total bytes mismatch')
 a.output.mkdir(parents=False,exist_ok=False)
 for name,data in decoded.items():
  with (a.output/name).open('xb') as f:f.write(data)
 print(json.dumps({'status':'NINE_BINARY_FILES_EXACT','files':9,'bytes':total}))
if __name__=='__main__':main()
