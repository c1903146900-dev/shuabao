extends SceneTree
var serial=0
var failures=[]
var Model=load('/workspace/shuabao-progression/scripts/progression/model.gd')
var config=JSON.parse_string(FileAccess.get_file_as_string('/workspace/shuabao-progression/data/progression/fixture.json'))
func cmd(m,a,p={}):
 serial+=1
 return m.command('qa-'+str(serial),a,p)
func check(ok,label,data={}):
 print(JSON.stringify({'check':label,'passed':ok,'data':data}))
 if not ok:failures.append(label)
func _initialize():
 var m=Model.new(config)
 cmd(m,'reward_minion',{'event_id':'seed','gold':1000,'xp':1700})
 var before=m.snapshot();var r=cmd(m,'reward_minion',{'event_id':'seed','gold':1000,'xp':1700})
 check(not r.accepted and m.snapshot()==before,'same death event with new command ID cannot repeat rewards')
 for slot in ['P','Q','E','R']:
  var maximum=3 if slot in ['P','R'] else 5
  for rank in range(maximum):
   r=cmd(m,'learn',{'slot':slot,'candidate':slot+'1','expected_rank':rank})
   check(r.accepted,'rank allocation '+slot+str(rank+1))
 check(m.snapshot().points==0 and m.snapshot().granted_level_ids.size()==18,'max ranks spend exactly 18 (fixture R gates)')
 for i in range(16):cmd(m,'undo_skill')
 check(m.snapshot().points==18,'full LIFO undo returns exactly 18')
 cmd(m,'context',{'phase':'safe','training':true});cmd(m,'respec')
 check(m.snapshot().points==18,'empty respec cannot mint points')
 var p=Model.new(config)
 cmd(p,'reward_minion',{'event_id':'seed','gold':1000,'xp':0});cmd(p,'enter_level',{'combat_level_id':'room1'})
 for i in range(3):cmd(p,'buy',{'item':'special'})
 cmd(p,'use_item',{'uid':1});cmd(p,'use_item',{'uid':2});before=p.snapshot();r=cmd(p,'use_item',{'uid':3})
 check(not r.accepted and p.snapshot()==before,'third special use atomically rejected')
 cmd(p,'context',{'phase':'combat'});cmd(p,'context',{'phase':'safe'});cmd(p,'enter_level',{'combat_level_id':'room1'})
 check(p.snapshot().special_uses==2,'same level and phase toggling do not replenish special uses')
 check(not cmd(p,'buy',{'item':'normal'}).accepted,'holding policy normal/special mutex')
 print('INDEPENDENT_FAILURES=',failures)
 quit(0 if failures.is_empty() else 1)
