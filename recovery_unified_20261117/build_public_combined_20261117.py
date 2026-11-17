"""Recompose only fixed-public backups. Offline; never executes game/engine."""
from pathlib import Path
import shutil,subprocess,json,hashlib,importlib.util,argparse
r=Path(__file__).parent.resolve();args=argparse.ArgumentParser();args.add_argument('--output',type=Path,default=r/'public_combined_20261117');opts=args.parse_args();b=r/'flow_trio_20261116';o=opts.output.resolve();i=r/'review_inputs';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not o.exists();assert sha(b/'boot/packs/runtime.pck')=='2c552be19883c8473d72717b9ccfcf2d4ce34155f3e12cfa962205aec4efe346';shutil.copytree(b/'runtime',o/'runtime')
patches=['ranged_sight_20261114/direct_fire_sight.patch','support_guard_range_20261114/guard_range.patch','support_escort_priority_20261116/support_escort_priority.patch','terminal_hex_20261116/host.patch','dash_edge_reconstruction_20261116/dash_edge.patch','dash_attack_pitch_20261111/dash_attack_pitch.patch']
for p in patches:
 q=subprocess.run(['git','apply','-'],cwd=o/'runtime',input=(i/p).read_bytes(),capture_output=True);assert q.returncode==0,(p,q.stderr)
shutil.copyfile(i/'terminal_hex_20261116/growth_controller.gd',o/'runtime/fengli_route_20261024/growth_controller.gd')
assert sha(o/'runtime/fengli_route_20261024/enemy_director.gd')=='324271748dc05975ea5a4e114bef79905bd33db48c8624c900e4dd05ec22da4b'
assert sha(o/'runtime/fengli_route_20261024/host.gd')=='52af785a7c78a06bbb50cf350f7a7939589227fcca177151f44b29afdc8707a6'
for p,v in json.loads((i/'dash_attack_pitch_20261111/SOURCE_HASHES.json').read_text()).items():assert sha(o/'runtime'/p)==v['after_sha256']
for p in ['scripts/combat/hero_combat_core.gd','scripts/combat/fengli_sector_geometry.gd','fengli_route_20261024/audio_policy.gd','fengli_route_20261024/audio_output.gd','fengli_route_20261024/input_router.gd']:assert sha(o/'runtime'/p)==sha(b/'runtime'/p),p
s=importlib.util.spec_from_file_location('late',r/'tools/rebuild_late.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);pack=m.seal(o,r/'source/rebuild_20261106');assert m.binding_check(o/'runtime')==258
report={'kind':'newly recomposed backed-only candidate NOT original e947','source_commit':'86b55f302568589fdc3fdeb57e8e270abb4833c1','pck_sha256':pack,'bindings':258,'included_patches':patches,'lost_local_only':['continuous sweep and timing/late-wall/callback revisions','release-aligned audio','contact voice priority','HUD hover keyboard buffer'],'engine_run':False,'parser_run':False,'selected_playable':False,'remote_upload':False}
(o/'RESTORE_REPORT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
