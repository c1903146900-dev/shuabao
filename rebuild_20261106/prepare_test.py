from pathlib import Path
import json,hashlib,shutil,sys
R=Path(__file__).resolve().parent;tag=sys.argv[2];stage=R/(tag+'_stage');shutil.copytree(R/sys.argv[1]/'boot',stage);shutil.copyfile(Path(sys.argv[3]),stage/'observer.gd');p=stage/'project.godot';p.write_text(p.read_text()+'\n[audio]\ndriver/driver="Dummy"\n');d=json.loads((stage/'descriptor.json').read_text());d['packs'][0]['path']=str(stage/'packs/runtime.pck');(stage/'descriptor.json').write_text(json.dumps(d,ensure_ascii=False,indent=2));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();pins=R/(tag+'_pins.json');pins.write_text(json.dumps({p.relative_to(stage).as_posix():sha(p) for p in sorted(stage.rglob('*')) if p.is_file()}));launch=R/('launch_'+tag+'.sh');launch.write_text(f'''#!/bin/bash
set -eu
cd {R.parent}
export XDG_CACHE_HOME="$PWD/rebuild_20261106/home/cache" XDG_DATA_HOME="$PWD/rebuild_20261106/home/data" XDG_CONFIG_HOME="$PWD/rebuild_20261106/home/config"
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
python3 -I -B recovery_20261018b/runtime_support/owned_runtime_guard.py --project {stage} --out {R}/{tag}_run --pins {pins} --pins-sha256 {sha(pins)} --binary /opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64 --binary-sha256 f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3 -- --script res://observer.gd --resolution 1180x663 -- --release-descriptor={stage}/descriptor.json --release-descriptor-sha256={sha(stage/'descriptor.json')} > {R}/launch_{tag}.log 2>&1
''');print(launch)
