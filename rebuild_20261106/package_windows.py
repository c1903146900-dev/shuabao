"""Assemble portable Windows candidate. This is not a Windows execution test."""
from pathlib import Path
import zipfile,json,hashlib,sys
R=Path(__file__).resolve().parent;c=R/sys.argv[1];out=R/sys.argv[2];assert not out.exists()
sha=lambda b:hashlib.sha256(b).hexdigest()
z=zipfile.ZipFile(R/'downloads/playable.zip');prefix='Shuabao_Fengli_Demo/';files={n[len(prefix):]:z.read(n) for n in z.namelist() if n.startswith(prefix) and not n.endswith('/')}
assert sha(files['Shuabao.exe'])=='1207fd8d65c15c0cea7cfbaa6f082772430444a3f6d8e3d589b964e1d21a7379'
old=json.loads(files['release_template.json']);d=json.loads((c/'boot/descriptor.json').read_text());pack=(c/'boot/packs/runtime.pck').read_bytes();assert sha(pack)==d['packs'][0]['sha256'];d['packs'][0]['path']='packs/runtime.pck';template=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();launcher=files['开始试玩.cmd'].decode()
for a,b in [(sha(files['release_template.json']),sha(template)),(old['packs'][0]['sha256'],sha(pack))]:
 assert a in launcher;launcher=launcher.replace(a,b)
files.update({'release_template.json':template,'packs/runtime.pck':pack,'开始试玩.cmd':launcher.encode()})
files['README_先读.txt']+='\r\n2026-11-06 重建开发候选，非此前丢失包的字节恢复。Windows实机未验证。WASD移动、鼠标左键普攻、Shift闪避；Esc/空格暂停，地图/商店内Esc先关闭界面。技能格上方+可学习技能。清房后走上方出口选下一房；休息/训练区按Enter或继续前进。\r\n'.encode()
files['SHA256SUMS.txt']=''.join(f'{sha(v)}  {k}\n' for k,v in sorted(files.items()) if k!='SHA256SUMS.txt').encode();assert b'/workspace/' not in template
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for k,v in files.items():z.writestr(prefix+k,v)
with zipfile.ZipFile(out) as z:
 assert z.testzip() is None
 for k,v in files.items():assert z.read(prefix+k)==v
receipt={'file':out.name,'bytes':out.stat().st_size,'sha256':sha(out.read_bytes()),'runtime_sha256':sha(pack),'static_roundtrip':'PASS','windows_execution':'NOT RUN','prior_lost_candidate03':False}
out.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
