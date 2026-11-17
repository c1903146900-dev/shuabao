from pathlib import Path
import subprocess,sys,json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path(__file__).resolve().parent/'source');a=p.parse_args();R=a.source.resolve()/'rebuild_20261106'
steps='''polish motion_polish02 flow_next
enemy_readability enemy_cues02
projectile_readability projectile_cues02
hit_feedback hit_feedback02
audio_sync audio_sync01
lob_readability lob_cues01
control control_continuity01
dash_timing dash_timing01
boss_readability boss_cues01
walk walk_layer01
player_hurt player_hurt01
player_recoil player_recoil01
q1_motion q1_motion01
e1_motion e1_motion01
combined_motion q2_e2_combo01
r1_motion r1_motion01
combined_exit combined_exit01
walk_sample walk_sample01
motion_combo motion_combo02
pouncer_motion motion_combo03
motion_combo04 motion_combo04
motion_combo05 motion_combo05
armored_break motion_combo06
e3_wind02 motion_combo07
q3_combo07 motion_combo08
shop_input motion_combo09
input_boundary motion_combo10
directional_hurt motion_combo11
ink_material motion_combo12
returnstroke_combo12 motion_combo13
boss_combo13 motion_combo14
enemy_defeat motion_combo15
r1_release motion_combo16
compact_hud motion_combo17
elixir_all elixir_all_recovered01'''
expected=json.loads((Path(__file__).resolve().parent/'EARLY_PACK_HASHES.json').read_text())
for row in steps.splitlines():
 s,*args=row.split();out=R/args[0]
 assert not out.exists(),str(out)
 subprocess.run([sys.executable,str(R/f'build_{s}.py'),*args],check=True)
 h=hashlib.sha256((out/'boot/packs/runtime.pck').read_bytes()).hexdigest()
 if args[0] in expected: assert h==expected[args[0]],(args[0],h,expected[args[0]])
 print('RESTORED',args[0],h,flush=True)
