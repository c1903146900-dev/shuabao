"""Build fresh front-only stage from exact worldFX03 parent; never run engine."""
from pathlib import Path
import argparse,hashlib,json,shutil
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
PARENT=ROOT/'worldfx_ui_source01/source/game'
PARENT_PINS=ROOT/'worldfx_ui_source01/SOURCE_PINS.json'
PAYLOAD=ROOT/'hero2d_replay01/recovered_64cc'
PARENT_SHA='c8bc6934c99fcb55ae60a765e4b59019142fcf16e64ed83f45839138d1a78b64'
PAYLOAD_SHA='64cc30997ac1205994fc5a1783e49092290b36478e86a12104ceebc7f91779a5'
ENTRY='yan_visual_attach_20261018/entry.gd'
ENTRY_SHA='50ed11e0c188bd4114dec928fc0d6f69820b2630244a66d1fbcdba3e83dcb764'
FILES=['capture.gd','controller.gd','geometry.gd','mapper.gd','renderer.gd','upper_q1_eight_original.png','lower_idle_walk_nine_original.png','neutral_parts_original.png']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('output');parser.add_argument('--reviewed-manifest-sha',required=True);args=parser.parse_args()
 out=Path(args.output).resolve(); assert not out.exists(),'fresh destination required'
 assert sha(HERE/'MANIFEST.json')==args.reviewed_manifest_sha
 reviewed=json.loads((HERE/'MANIFEST.json').read_text())
 for name,row in reviewed['files'].items():assert sha(HERE/name)==row['sha256'],name
 assert sha(PARENT_PINS)==PARENT_SHA
 pins=json.loads(PARENT_PINS.read_text());assert len(pins)==3046
 assert {str(x.relative_to(PARENT)) for x in PARENT.rglob('*') if x.is_file()}==set(pins)
 for name,digest in pins.items():assert sha(PARENT/name)==digest,name
 assert sha(PAYLOAD/'MANIFEST.json')==PAYLOAD_SHA
 assets=json.loads((PAYLOAD/'MANIFEST.json').read_text())['files']
 for name in FILES+['entry.gd']:assert sha(PAYLOAD/name)==assets[name]['sha256'],name
 assert sha(PARENT/ENTRY)==ENTRY_SHA
 # copy2 creates independent new inodes even when the frozen parent is deduplicated.
 shutil.copytree(PARENT,out,copy_function=shutil.copy2)
 module=out/'yan_front_hero_20261018';assert not module.exists();module.mkdir()
 for name in FILES:shutil.copy2(PAYLOAD/name,module/name)
 shutil.copy2(PAYLOAD/'entry.gd',out/ENTRY)
 fixture=out/'yan_front_combat_probe01';assert not fixture.exists();fixture.mkdir()
 shutil.copy2(HERE/'runner.gd',fixture/'runner.gd')
 actual={str(x.relative_to(out)):sha(x) for x in sorted(out.rglob('*')) if x.is_file()}
 assert len(actual)==3055
 assert set(actual)-set(pins)=={'yan_front_hero_20261018/'+n for n in FILES}|{'yan_front_combat_probe01/runner.gd'}
 assert {n for n in pins if actual[n]!=pins[n]}=={ENTRY}
 report={'parent_pins_sha256':PARENT_SHA,'payload_manifest_sha256':PAYLOAD_SHA,'fixture_manifest_sha256':args.reviewed_manifest_sha,'count':len(actual),'files':actual,'native_run':False,'scope':'front_partial_world_sample'}
 (out.parent/(out.name+'_PINS.json')).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'count':len(actual),'pins_sha256':sha(out.parent/(out.name+'_PINS.json')),'CPU_IO_CLEAR':True}))
if __name__=='__main__':main()
