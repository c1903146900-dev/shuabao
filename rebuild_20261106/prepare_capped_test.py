"""Create a fresh 60 FPS test profile; original guard and physics remain unchanged."""
from pathlib import Path
import sys, subprocess, hashlib, json, shlex
r=Path(__file__).resolve().parent
if len(sys.argv)<4:raise SystemExit('usage: prepare_capped_test.py BUNDLE TAG OBSERVER [USER_ARGS...]')
bundle,tag,observer=sys.argv[1:4]
assert tag and all(c.isalnum() or c=='_' for c in tag)
subprocess.run([sys.executable,'-I','-B',str(r/'prepare_test.py'),bundle,tag,observer],check=True)
stage=r/(tag+'_stage');project=stage/'project.godot';s=project.read_text();assert 'run/max_fps=' not in s
project.write_text(s.replace('[application]\n','[application]\nrun/max_fps=60\n',1))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pins=r/(tag+'_pins.json');old=sha(pins);pins.write_text(json.dumps({p.relative_to(stage).as_posix():sha(p) for p in sorted(stage.rglob('*')) if p.is_file()}))
launch=r/('launch_'+tag+'.sh');s=launch.read_text();assert s.count(old)==1;s=s.replace(old,sha(pins))
if sys.argv[4:]:
 assert s.count(' > ')==1;s=s.replace(' > ',' '+' '.join(shlex.quote(a) for a in sys.argv[4:])+' > ')
launch.write_text(s)
print(json.dumps({'profile_max_fps':60,'guard_unchanged':True,'physics_settings_unchanged':True,'stage':str(stage),'pins_sha256':sha(pins)}))
