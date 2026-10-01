import json
from pathlib import Path
root=Path(__file__).parent/'evidence/round4-window'
def read(i):
 p=root/f'step-{i:02}-execute_game_script.json';x=json.loads(json.loads(p.read_text())['content'][0]['text']);return json.loads(x.replace('\\"','"')) if isinstance(x,str) else x
states={i:read(i) for i in [3,6,9,12,15,18,21,25,27]}
a,b=states[21]['state']['combat'],states[25]['state']['combat']
report={'checkpoint':'a3dd6b47af52b652d293ccc74197060628a6a316','source':'OS XTest / real Godot MCP readback','freeze':{'wall_seconds':(root/'step-25-execute_game_script.json').stat().st_mtime-(root/'step-21-execute_game_script.json').stat().st_mtime,'same_hero':a['hero']==b['hero'],'same_world_time':a['world_time']==b['world_time'],'phase':b['phase']},'restart':{'phase':states[27]['state']['combat']['phase'],'enemy_count':len(states[27]['state']['combat']['enemies'])},'hover_latch_loss_frames':[f for f in states[3]['frames'] if f['physical_w'] and not f['held']], 'panel':{'opens':states[6]['panel_opens'],'attacking_while_open':sum(f['panel'] and f['attacking'] for f in states[6]['frames']),'attack_start_events':[e for e in states[6]['events'] if e['kind']=='attack_started'],'growth':states[6]['state']['growth']},'space':{'inputs':[e for e in states[18]['inputs'] if e.get('key')==32],'self_rescue_events':[e for e in states[18]['events'] if e['kind']=='self_rescue'],'final_phase':states[18]['state']['combat']['phase'],'unexpected_panel_open':states[18]['state']['panel_open'],'hp':states[18]['state']['combat']['hero']['hp']},'active_ui':{},'animation':{},'reward_state':states[21]['state']['growth']}
for i,tag in [(9,'e3'),(12,'e2'),(15,'r2')]:
 active=[f for f in states[i]['frames'] if f['e3']>0 or tag in f['q']]
 report['active_ui'][tag]=active[:2]
 report['animation'][tag]=sorted(set(f['clip'] for f in active))
Path(__file__).with_name('round4_window_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({'freeze':report['freeze'],'restart':report['restart'],'panel_opens':report['panel']['opens'],'attacking_while_panel':report['panel']['attacking_while_open'],'space':report['space'],'animations':report['animation']},ensure_ascii=False))
