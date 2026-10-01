import json
from pathlib import Path
root=Path(__file__).parent/'evidence/round5-window'
def read(i):
 x=json.loads(json.loads((root/f'step-{i:02}-execute_game_script.json').read_text())['content'][0]['text']);return json.loads(x.replace('\\"','"')) if isinstance(x,str) else x
s={i:read(i) for i in [3,6,9,12,15,19,21]}
hero=s[3]['state']['combat']['hero']
report={'checkpoint':'15e694e2e260953076d37cc81cf0c23eaa658487','input':'OS XTest with real MCP readback','hover':{'physical_hold_missing_held_w':sum(f['physical_w'] and not f['held'].get('87',False) for f in s[3]['frames']),'end_position':hero['position']},'panels':{'opens':s[6]['panel_opens'],'attack_latch_while_open':sum(f['panel'] and f['attacking'] for f in s[6]['frames']),'attack_start_events':[e for e in s[6]['events'] if e['kind']=='attack_started']},'rescue':{},'freeze':{},'restart':{'phase':s[21]['state']['combat']['phase'],'enemies':len(s[21]['state']['combat']['enemies'])},'growth_after_win':s[15]['state']['growth']}
for i,label in [(9,'short_space'),(12,'held_space')]:
 v=s[i];report['rescue'][label]={'self_rescue_events':[e for e in v['events'] if e['kind']=='self_rescue'],'space_inputs':[e for e in v['inputs'] if e.get('key')==32],'unexpected_panel_after_rescue':any(f['phase']=='combat' and f['t']>2 and f['panel'] for f in v['frames']),'final_panel':v['state']['panel_open'],'final_phase':v['state']['combat']['phase']}
a,b=s[15]['state']['combat'],s[19]['state']['combat'];report['freeze']={'same_hero':a['hero']==b['hero'],'same_clock':a['world_time']==b['world_time'],'phase':b['phase'],'wall_seconds':(root/'step-19-execute_game_script.json').stat().st_mtime-(root/'step-15-execute_game_script.json').stat().st_mtime}
report['passed']=report['hover']['physical_hold_missing_held_w']==0 and report['panels']['opens']==20 and report['panels']['attack_latch_while_open']==0 and all(not r['unexpected_panel_after_rescue'] and len(r['self_rescue_events'])==1 for r in report['rescue'].values()) and report['freeze']['same_hero'] and report['freeze']['same_clock'] and report['freeze']['wall_seconds']>=60 and report['restart']['phase']=='preparation'
Path(__file__).with_name('round5_window_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False));raise SystemExit(0 if report['passed'] else 1)
