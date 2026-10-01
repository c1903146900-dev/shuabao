"""Run build then verify in separate check.py sessions; SDK uses real tools/call."""
import argparse
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def call(tool,args=None,wait=0,expect=None):
    out={'server':'godot','tool':tool,'arguments':args or {}}
    if wait: out['wait_after']=wait
    if expect: out['expect_text']=expect
    return out

def editor(expr,wait=0):return call('execute_editor_script',{'code':expr},wait)
def game(expr,wait=0):return call('execute_game_script',{'code':expr},wait)

def build():
    steps=[call("get_project_info",wait=35)]
    for p in ['scripts/audio/combat_audio.gd','scripts/audio/audio_demo.gd','tests/audio/editor_probe.gd','tests/audio/mcp_probe.gd','tests/audio/playback_drain.gd','tests/audio/lifecycle_suite.gd']:
        steps.append(call('create_script',{'script_path':'res://'+p,'content':(ROOT/p).read_text(),'overwrite':True}))
    steps += [call('create_scene',{'scene_path':'res://scenes/audio/editor_probe.tscn','root_type':'Node','overwrite':True}),
        call('open_scene',{'scene_path':'res://scenes/audio/editor_probe.tscn'},1),
        call('attach_script',{'node_path':'.','script_path':'res://tests/audio/editor_probe.gd'},1),
        call('save_scene'), editor('scan()',3), editor('configure_imports()',3), editor('inventory()')]
    for name,kind,script in [('combat_audio','Node','scripts/audio/combat_audio.gd'),('audio_demo','Control','scripts/audio/audio_demo.gd'),('mcp_probe','Control','tests/audio/mcp_probe.gd')]:
        steps += [call('create_scene',{'scene_path':f'res://scenes/audio/{name}.tscn','root_type':kind,'overwrite':True}),
            call('open_scene',{'scene_path':f'res://scenes/audio/{name}.tscn'},1),
            call('attach_script',{'node_path':'.','script_path':'res://'+script}), call('save_scene')]
    return steps

def verify():
    steps=[call('open_scene',{'scene_path':'res://scenes/audio/editor_probe.tscn'},1), editor('inventory()'),
        call('open_scene',{'scene_path':'res://scenes/audio/mcp_probe.tscn'},1),
        call('play_scene',{'mode':'current'},12)]
    for id in ['sword','hit','hit_heavy','dash','hurt','enemy_die','q_thrust','e_overload','r_slam','ui_confirm','ui_reject','level_up','settlement']:
        steps.append(game(f'probe_event("{id}")'))
    steps += [game('probe_limits()'),game('probe_settings()',.12),game('get_node("CombatAudio").snapshot()',1.1),
        game('get_node("CombatAudio").snapshot()'),game('inject_key(69)',.06),game('release_key(69)'),game('report()'),
        call('get_game_screenshot'),call('stop_scene')]
    return steps

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['build','verify','lifecycle']);p.add_argument('--out',required=True);a=p.parse_args()
    workflow=build() if a.mode=='build' else verify()
    if a.mode=='lifecycle':
        workflow=workflow[:-1]+[game('start_lifecycle()',35),game('get_node("/root/AudioLifecycleSuite").report()'),call('stop_scene')]
    Path(a.out).write_text(json.dumps(workflow,indent=2))
