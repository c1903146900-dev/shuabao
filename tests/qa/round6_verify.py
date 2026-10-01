import json, math
from pathlib import Path
root=Path(__file__).parent
folder=root/'evidence/round6-two-room-final'
s=json.loads((folder/'os-samples.json').read_text())
checks=[]
def check(ok,label,detail=None):checks.append(dict(check=label,passed=bool(ok),detail=detail))
def st(k):return s[k]['state']
def g(k):return st(k)['growth']
def c(k):return st(k)['combat']
def h(k):return c(k)['hero']
check(g('learned')['skills']['Q']['rank']==1 and g('learned')['points']==0,'OS learn spends initial point')
check((g('room1_victory')['gold'],g('room1_victory')['level'],g('room1_victory')['xp'],len(g('room1_victory')['reward_ids']))==(450,2,80,3),'first room natural kills award correct unique rewards and level')
for before,after in [('room1_victory','room1_frozen'),('true_dead','dead_frozen')]:
 duration=(s[after]['wall']-s[before]['wall'])/1000
 check(h(before)==h(after) and c(before)['world_time']==c(after)['world_time'] and duration>=60,'actual wall-clock freeze '+before,{'seconds':duration,'cooldowns':h(before)['cooldowns']})
check(g('upgraded')['skills']['Q']['rank']==2 and g('upgraded')['points']==0,'OS spends earned point upgrading Q')
check(s['purchased']['AD']==40 and g('purchased')['gold']==0 and any(i['id']=='iron_blade' for i in g('purchased')['inventory']),'OS purchases iron blade with earned gold; AD hook projects 40')
check(h('purchased')['hp']==h('room1_victory')['hp'] and h('purchased')['cooldowns']==h('room1_victory')['cooldowns'],'UI upgrade and equipment purchase preserve frozen HP/CD',{'hp_was_full':h('purchased')['hp']==h('purchased')['max_hp']})
check(g('room2_start')['inventory']==g('purchased')['inventory'] and g('room2_start')['skills']==g('purchased')['skills'] and g('room2_start')['reward_ids']==g('purchased')['reward_ids'],'next room uses same inventory skills and credited reward ledger')
elapsed=c('room2_start')['world_time']-c('purchased')['world_time']
check(all(abs(v-max(0,h('purchased')['cooldowns'][k]-elapsed))<.026 for k,v in h('room2_start')['cooldowns'].items()),'next room CD follows elapsed battle time',{'elapsed_world':elapsed})
check((g('room2_victory')['gold'],g('room2_victory')['level'],g('room2_victory')['xp'],len(g('room2_victory')['reward_ids']))==(450,3,135,6),'second room rewards keep separate unique IDs')
id2=c('room2_victory')['combat_level_id']
attacks=[e for e in s['room2_victory']['events'] if e['kind']=='damage' and e.get('source')=='attack' and e['combat_level_id']==id2]
check(any(e['amount']==40 for e in attacks),'second room real OS attack delivers equipment AD damage',{'attack_amounts':[e['amount'] for e in attacks]})
check(h('room2_victory')['hp']<h('room2_victory')['max_hp'],'real enemies caused damage during second room')
check(g('downed')['xp']==g('room3_paid_kill')['xp'] and g('downed')['gold']==g('room3_paid_kill')['gold'],'first down keeps earned XP and gold')
check(c('rescued')['phase']=='combat' and h('rescued')['self_rescue_used'] and not st('rescued')['panel_open'],'OS Space rescues once without unwanted panel')
a,b=g('downed'),g('true_dead')
check(b['xp']==math.floor(a['xp']*.7) and all(b[k]==a[k] for k in ['level','points','gold','skills','inventory','reward_ids']),'true death deducts current XP only',{'before':a['xp'],'after':b['xp'],'level':b['level'],'gold':b['gold']})
for label in ['retry','retry_repeated']:
 check(c(label)['phase']=='combat' and c(label)['combat_level_id']==c('true_dead')['combat_level_id'] and all(g(label)[k]==b[k] for k in ['xp','level','points','gold','skills','inventory','reward_ids','death_ids']) and h(label)['self_rescue_used'],'OS F5 retains same-room ledger '+label)
 dead_ids=lambda k:sorted(e['actor_id'] for e in c(k)['enemies'] if e['dead'])
 check(dead_ids(label)==dead_ids('true_dead') and st(label)['kills']==st('true_dead')['kills'],'F5 does not respawn paid corpses '+label,dead_ids(label))
 check(all(h(label)['cooldowns'][k]<=v+.001 for k,v in h('true_dead')['cooldowns'].items()),'F5 keeps cooldown state '+label)
for label,v in s.items():
 gg=v['state']['growth'];cost=sum((1+2*(z['rank']-1) if slot=='R' and z['rank'] else z['rank']) for slot,z in gg['skills'].items())
 check(gg['points']+cost==len(gg['granted_level_ids'])==gg['level']<=18,'point conservation at '+label)
 check(len(set(gg['reward_ids']))==len(gg['reward_ids']),'no duplicate reward identity at '+label)
 check(all(v['state']['hud'][k]==gg[k] for k in ['xp','level','points','gold']),'HUD ledger agreement at '+label)
result={'sha':'a294d0420f5b5a23027d94755a9f78509b6929b4','input':'OS XTest; observation through standard MCP','checks':checks,'failures':[r for r in checks if not r['passed']],'limits':['Linux editor embedded viewport only, not exported package or Windows','OS growth covers observed levels only; level18 requires separate fixture','Equipment bought at full HP on OS route; injured HP tested separately in integration fixture','Repeat callback tests are separate headless integration fixture, not natural player inputs','Enter entry route failed separately as QA-008']}
(root/'round6_window_report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps({'failures':result['failures']},ensure_ascii=False));raise SystemExit(bool(result['failures']))
