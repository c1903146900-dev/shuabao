from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,importlib.util
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=a.root.resolve();o=a.output.resolve();here=Path(__file__).parent;b=r/'public_combined_20261117';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();report=json.loads((here/'BUILD.json').read_text());assert not o.exists();assert sha(b/'boot/packs/runtime.pck')==report['base'];pins=json.loads((here/'SOURCE_HASHES.json').read_text());shutil.copytree(b/'runtime',o/'runtime')
for rel,h in pins.items():assert sha(o/'runtime'/rel)==h['before']
p=subprocess.run(['git','apply','-'],input=(here/'changes.patch').read_bytes(),cwd=o/'runtime',capture_output=True);assert p.returncode==0,p.stderr
for rel,h in pins.items():assert sha(o/'runtime'/rel)==h['after']
s=importlib.util.spec_from_file_location('late',r/'tools/rebuild_late.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);h=m.seal(o,r/'source/rebuild_20261106');assert h==report['candidate'];assert m.binding_check(o/'runtime')==258;print(h)
