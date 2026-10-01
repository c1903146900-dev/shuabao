import json
from pathlib import Path
root=Path(__file__).parent
s=json.loads((root/'evidence/round8-q2-e1-final/os-samples.json').read_text())
p=json.loads((root/'evidence/round8-p2-e3/os-samples.json').read_text())
checks=[]
def check(ok,label,data=None):checks.append({'check':label,'passed':bool(ok),'data':data})
def hero(v):return v['state']['combat']['hero']
def events(v,kind):return [x for x in v['events'] if x['event']['kind']==kind]
a=s['q2_finished'];impacts=[x for x in events(a,'enemy_impact') if x['event'].get('hit') and x['hero']['immune'] and x['hero']['untargetable'] and 'q2' in x['hero']['state']]
check(s['before_q2']['state']['growth']['skills']['Q']['candidate']=='Q2','Q2 actually learned through UI')
check(len(impacts)>=1 and all(x['hero']['hp']==240 for x in impacts),'OS Q2 immune to actual enemy impacts that geometrically hit',impacts)
check(not hero(a)['cast_state'].get('q2') and not hero(a)['untargetable'] and hero(a)['cooldowns']['q']>0,'OS Q2 ends chain and starts CD')
mark=hero(s['mark_recast'])['cast_state']['e1'];after=s['e1_recast_finished']
check(mark['stage']=='marked' and bool(events(after,'e1_pierce')) and not hero(after)['cast_state'].get('e1') and hero(after)['cooldowns']['e']>0,'OS E1 marked target recast performs pierce then CD')
target=hero(s['mark_attack'])['cast_state']['e1']['target'];after=s['marked_target_dead']
check(any(x['event'].get('target')==target and x['event'].get('source')=='attack' for x in events(after,'kill')) and bool(events(after,'e1_finished')) and not hero(after)['cast_state'].get('e1') and hero(after)['cooldowns']['e']>0,'OS basic attack kills marked target; E1 invalidates and starts CD',{'target':target})
check(s['done']['state']['combat']['phase']=='victory' and s['done']['state']['room_number']==3,'OS Q2/E1 three-room route finishes after natural rescue and cooldown wait')
v=p['P2_during_E3'];trigger=events(v,'low_health_passive')
check(trigger and trigger[-1]['hero']['e3']>0 and trigger[-1]['hero']['state'].get('e_reset_credit') and trigger[-1]['hero']['cd']['q']==0,'OS true low-health P2 triggers while E3 remains active',trigger)
first=hero(p['credited_E3_end']);second=hero(p['second_E3_end'])
check(first['overload_left']==0 and first['cooldowns']['e']==0 and not first['cast_state'].get('e_reset_credit'),'OS first E3 end spends exactly one reset credit')
check(hero(p['second_E3_started'])['overload_left']>0 and second['overload_left']==0 and second['cooldowns']['e']>30,'OS next E3 end returns normal cooldown; credit not infinite',{'second_E_CD':second['cooldowns']['e']})
check(p['done']['state']['combat']['phase']=='combat' and hero(p['done'])['hp']>0,'OS player stayed alive by actual movement during P2/E3 end checks')
report={'sha':'c1b20bc8da414452c113936b26ce9a4874bb733d','input':'OS XTest with read-only MCP; no enemy/HP/skill/XP/AI fixture edits','checks':checks,'failures':[x for x in checks if not x['passed']],'paths':['Q2 real overlapping enemy impacts','E1 marked recast','E1 marked-target killed by attack','P2 while E3 active and one-shot reset credit'],'not_claimed':['QA009 cross-room damage is simulation fixture only','R2 cumulative 1/2/3 is simulation fixture, not OS level6 play','all 54 combos are rank1 fixture coverage, not natural complete play']}
(root/'round8_window_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({'failures':report['failures']},ensure_ascii=False));raise SystemExit(bool(report['failures']))
