import json,math
from pathlib import Path
root=Path(__file__).parent
s=json.loads((root/'evidence/round7-sustain/os-samples.json').read_text())
b=json.loads((root/'evidence/round7-build-window/os-samples.json').read_text())
checks=[]
def check(ok,label,data=None):checks.append({'check':label,'passed':bool(ok),'data':data})
def state(k,d=s):return d[k]['state']
def g(k,d=s):return state(k,d)['growth']
def h(k,d=s):return state(k,d)['combat']['hero']
def equal(a,z):return abs(a-z)<.0001
for name,room in [('enter_short',1),('kp_long',2),('enter_long',3),('kp_short',4)]:
 v=state(name);check(v['room_number']==room and v['combat']['phase']=='combat' and not v['panel_open'],'exclusive OS Enter cycle '+name)
check(state('tab_enter_gui')['room_number']==0 and state('tab_enter_gui')['panel_open'],'Tab selects GUI; Enter activates without starting combat')
check(state('combat_enter_GUI')['panel_open'] and not state('combat_GUI_closed')['panel_open'] and state('combat_enter_GUI')['room_number']==3,'new Enter cycle in combat retains GUI keyboard activation')
inputs=s['kp_short']['inputs']
for key in [4194309,4194310]:
 echo=[x for x in inputs if x.get('key')==key and x.get('echo')]
 check(len(echo)>0,'OS auto-repeat was actually delivered '+str(key),{'echoes':len(echo)})
check(h('HP_equipped')['max_hp']==340 and h('before_HP')['max_hp']==240 and h('HP_equipped')['hp']==h('before_HP')['hp'] and h('HP_equipped')['cooldowns']==h('before_HP')['cooldowns'],'OS HP purchase raises cap without healing injured HP or resetting CD',{'hp':h('before_HP')['hp']})
check(g('holding_mutex')==g('normals_bought') and s['holding_mutex']['last_result']['reason']=='recovery_mutex','OS holding-type purchase mutex is atomic')
for before,after in [('before_normal','normal1'),('normal1','normal2'),('normal2','normal3'),('normal3','normal4_topoff')]:
 check(equal(h(after)['hp'],min(340,h(before)['hp']+61.2)) and h(after)['cooldowns']==h(before)['cooldowns'],'OS normal actual heal '+after,{'before':h(before)['hp'],'after':h(after)['hp']})
check(s['normal_full_reject']['last_result']['reason']=='full_health' and g('normal_full_reject')==g('before_full_reject') and h('normal_full_reject')==h('before_full_reject'),'OS full-health use does not consume or alter HP/CD')
for before,after,n in [('before_special','special1',1),('special1','special2',2)]:
 check(equal(h(after)['hp'],h(before)['hp']+102) and g(after)['special_uses']==n and h(after)['cooldowns']==h(before)['cooldowns'],'OS special actual heal and count '+after,{'before':h(before)['hp'],'after':h(after)['hp']})
check(s['special3_rejected']['last_result']['reason']=='special_cap' and g('special3_rejected')==g('special2') and h('special3_rejected')==h('special2') and h('special2')['hp']<340,'OS third special rejected below full HP without mutation')
check(g('room5_reset')['special_uses']==0 and g('room5_reset')['inventory']==g('special3_rejected')['inventory'],'OS next room resets count without replenishing potions')
check(s['combat_bag']['controls']['use_2']['disabled'] and len(s['combat_bag']['receipts'])==len(s['combat_use_blocked']['receipts']) and g('combat_bag')['inventory']==g('combat_use_blocked')['inventory'],'OS disabled combat use does not emit or consume')
check(s['special_new_room']['last_result']['accepted'] and g('special_new_room')['special_uses']==1 and equal(h('special_new_room')['hp'],min(340,h('room5_victory')['hp']+102)),'OS leftover special works in new room after victory')
check(equal(b['AS_equipped']['stats']['attack_speed'],1.904) and h('AS_equipped',b)['cooldowns']==h('before_AS',b)['cooldowns'],'OS AS component changes consumer without resetting active cooldown')
check(equal(b['CDR_equipped']['stats']['cdr'],.06) and h('CDR_equipped',b)['cooldowns']==h('before_CDR',b)['cooldowns'],'OS CDR component does not rewrite current cooldown')
selected=g('hex_selected',b)['selected_hex'];check(len(selected)==1 and b['hex_selected']['stats']!=b['CDR_equipped']['stats'] and h('hex_selected',b)['hp']==h('CDR_equipped',b)['hp'] and h('hex_selected',b)['cooldowns']==h('CDR_equipped',b)['cooldowns'],'OS numeric hex selection changes real stats without HP/CD refill',{'selected':selected,'before':b['CDR_equipped']['stats'],'after':b['hex_selected']['stats']})
dash=[e for e in b['CDR_dash']['events'] if e['kind']=='dash']
last=dash[-1] if dash else None
elapsed=state('CDR_dash',b)['combat']['world_time']-last['world_time'] if last else None
expected=max(0,3.2*(1-b['CDR_dash']['stats']['cdr'])-elapsed) if last else -1
check(last and abs(h('CDR_dash',b)['cooldowns']['shift']-expected)<.03,'OS new dash uses actual CDR',{'expected_remaining':expected,'actual':h('CDR_dash',b)['cooldowns']['shift']})
room=state('room5_victory',b)['combat']['combat_level_id']
times=[e['world_time'] for e in b['room5_victory']['events'] if e['kind']=='attack_started' and e['combat_level_id']==room]
intervals=[z-a for a,z in zip(times,times[1:])]
AS=b['hex_selected']['stats']['attack_speed'];check(intervals and min(intervals)>=1/AS-.025 and min(intervals)<=1/AS+.035,'OS real held-attack cadence consumes AS',{'AS':AS,'intervals':intervals})
report={'sha':'c1b20bc8da414452c113936b26ce9a4874bb733d','input':'OS XTest; MCP observes without game-state fixtures','checks':checks,'failures':[r for r in checks if not r['passed']],'scope_notes':['Sustain samples completed through next-room special use before a later MCP timeout; no claim that the whole sustain workflow completed','Build stats and hexes are a separate fresh natural OS run','F5 potion-count retention, six-slot refusal, same-room sell-switch use mutex and HP trade/respec loops are separate headless fixtures','Skill-dependent hexes are intentionally closed; dormancy behavior is not claimed','Linux editor window only; no Windows/export package acceptance']}
(root/'round7_window_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({'failures':report['failures']},ensure_ascii=False));raise SystemExit(bool(report['failures']))
