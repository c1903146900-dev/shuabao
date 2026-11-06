from pathlib import Path
import zipfile,json,hashlib,struct
R=Path(__file__).resolve().parent;z=zipfile.ZipFile(R/'downloads/playable.zip');delta=zipfile.ZipFile(R/'downloads/delta238.zip');m=json.loads(delta.read('manifest.json'))
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha((R/'downloads/playable.zip').read_bytes())=='0a708d03e38856139745820c3e1d0243ef87fde55d32577b532bba0ecff16efc'
def unpack(b):
 magic,version,a,c,d,flags,base,di=struct.unpack_from('<6IQQ',b);assert magic==0x43504447 and version==3
 count=struct.unpack_from('<I',b,di)[0];pos=di+4;out={}
 for _ in range(count):
  n=struct.unpack_from('<I',b,pos)[0];pos+=4;name=b[pos:pos+n].rstrip(b'\0').decode().removeprefix('res://');pos+=n
  off,size=struct.unpack_from('<QQ',b,pos);md=b[pos+16:pos+32];flag=struct.unpack_from('<I',b,pos+32)[0];pos+=36;assert flag==0
  value=b[base+off:base+off+size];assert hashlib.md5(value).digest()==md;out[name]=value
 return out
runtime=unpack(z.read('Shuabao_Fengli_Demo/packs/runtime.pck'));out=R/'restored238';assert not out.exists();out.mkdir();origins={}
for item in m['members']:
 name=item['path'];assert not name.startswith('/') and '..' not in Path(name).parts
 candidates=[('delivered',runtime.get(name)),('payload',delta.read('payload/'+item['origin']['path']) if item['origin']['kind']=='payload' else None)]
 for origin,b in candidates:
  if b is not None and len(b)==item['bytes'] and sha(b)==item['sha256']:break
 else:raise Exception(name)
 p=out/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);origins[name]=origin
inv=[{'path':x['path'],'bytes':x['bytes'],'sha256':x['sha256']} for x in m['members']];fingerprint=sha(json.dumps(inv,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode());assert fingerprint==m['target']['sha256'];print(m['target']);print({k:list(origins.values()).count(k) for k in set(origins.values())})
boot=R/'boot234';boot.mkdir()
for name,b in unpack(z.read('Shuabao_Fengli_Demo/Shuabao.pck')).items():
 p=boot/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
(boot/'release_template.json').write_bytes(z.read('Shuabao_Fengli_Demo/release_template.json'))
(R/'RESTORATION_RECEIPT.json').write_text(json.dumps({'target':m['target'],'origins':origins,'fingerprint':fingerprint,'prior_candidate03_recovered':False},indent=2))
