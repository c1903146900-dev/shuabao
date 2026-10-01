import json,collections
from pathlib import Path
q=Path(__file__).parent;e=q/'evidence';report={'baseline':'ae673bf01b03ddf1e046730244ecb5ce9b8d9180','controlled':{},'natural':{},'listened':False}
def read(folder,i):
 p=e/folder/f'step-{i:02}-execute_game_script.json';raw=json.loads(p.read_text());assert not raw.get('application_error')
 v=json.loads(raw['content'][0]['text'])
 return json.loads(v.replace('\\"','"')) if isinstance(v,str) else v
rows=read('round9-controlled2',6)
for row in rows:
 fs=row['frames'];expected='attack' if row['ability']=='e2' else 'ultimate'
 same=all(f['before']['clip']==f['after']['clip']==expected and abs(f['before']['position']-f['after']['position'])<1e-8 for f in fs)
 increasing=all(fs[i]['after']['position']>fs[i-1]['after']['position'] for i in range(1,len(fs)))
 report['controlled'][row['ability']+'_sampling']={'pass':row['request']['accepted'] and same and increasing,'last':fs[-1]['after']}
 if row['ability']=='r1':report['controlled']['r1_time']={'pass':abs(fs[-1]['after']['position']/fs[-1]['after']['length']-.9/1.1)<1e-5,'world_time':fs[-1]['after']['world']}
for i,label,white in [(7,'first_hit',['enemy_1']),(9,'overlap',['enemy_1','enemy_2']),(11,'first_restored',['enemy_2']),(13,'all_restored',[])]:
 v=read('round9-controlled2',i)
 report['controlled'][label]={'pass':all(a and all(m['flash']==(id in white) and m['original']==(id not in white) for m in a) for id,a in v.items()),'mesh_counts':{k:len(a) for k,a in v.items()}}
v=read('round9-controlled2',15);ds=[z for z in v['events'] if z['kind']=='damage'];hits=v['after'].get('hit',0)-v['before'].get('hit',0)
report['controlled']['damage_group']={'pass':len(ds)==4 and len({z['target'] for z in ds})==2 and hits==1,'packets':len(ds),'hit_cues':hits}
report['controlled']['duplicate_events']={'pass':v['after']==v['replay']}
report['controlled']['audio_burst_mute']={'pass':sum(v['burst_accept'])==1 and v['muted']['active']==0 and not v['muted_play'] and v['unmuted_play'] and v['pool']['active']==8}
p=e/'round9-high/step-05-execute_game_script.json'
if p.exists():
 v=read('round9-high',5)
 if v:
  ps=v['players'];peak=max(z['active'] for z in ps);per=max((max(collections.Counter(a['id'] for a in z['voices']).values(),default=0) for z in ps),default=0)
  report['controlled']['sustained_high_attack']={'pass':v['accepted']>=10 and peak<=8 and per<=2,'accepted_attacks':v['accepted'],'attack_speed':v['attack_speed'],'peak_players':peak,'peak_same_sound':per,'counts_before':v['before'],'counts_after':v['after']}
p=e/'round9-window2/os-samples.json'
if p.exists():
 ss=json.loads(p.read_text());finish=json.loads((p.parent/'os-finish.json').read_text())
 report['natural']['completion']={'pass':finish['completed'],'stages':list(ss)}
 for label,muted in [('muted',True),('unmuted',False)]:
  v=ss[label]['state']['audio']['player'];report['natural'][label]={'pass':v['muted']==muted and (not muted or v['active']==0),'player':v}
 for label in ['room1_victory','room2_victory']:report['natural'][label]={'pass':ss[label]['state']['combat']['phase']=='victory','audio':ss[label]['state']['audio']}
 report['natural']['distinct_room_ids']={'pass':ss['room1_victory']['state']['combat']['combat_level_id']!=ss['room2_victory']['state']['combat']['combat_level_id'] and ss['room2_victory']['state']['room_number']==2}
 report['natural']['actual_players']={'pass':'natural_audio' in ss,'snapshot':ss.get('natural_audio',{}).get('state',{}).get('audio',{})}
report['failures']=[f'{section}/{k}' for section in ['controlled','natural'] for k,v in report[section].items() if not v['pass']]
(q/'round9_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
