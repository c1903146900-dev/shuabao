extends SceneTree
const Room=preload('res://scripts/integration/room.gd')
const Consumer=preload('res://scripts/integration/consumers.gd')
var checks=[]
var serial=0
func check(ok,label,data={}):checks.append({'check':label,'passed':ok,'data':data})
func cmd(m,action,args={}):
 serial+=1
 return m.command('qa7-%d'%serial,action,args)
func uid(m,item):
 for e in m.snapshot().inventory:
  if e.id==item:return e.uid
 return -1
func _initialize():call_deferred('run_checks')
func fresh():
 var r=Room.new();root.add_child(r);r.set_physics_process(false)
 cmd(r.ledger.model,'reward_minion',{'event_id':'fixture','gold':20000,'xp':0})
 r.start_room()
 for e in r.simulation.enemies:r.simulation.damage_enemy(e,100000,'qa_fixture',0)
 r.simulation.step(.05)
 r.simulation.hero.hp=10.0;r.simulation.hero.cooldowns.q=4.0
 return r
func run_checks():
 var r=fresh();var m=r.ledger.model;var sim=r.simulation;var con=r.consumers
 for i in range(3):cmd(m,'buy',{'item':'special_tonic'})
 var before=m.snapshot();var id=uid(m,'special_tonic');sim.phase='preparation'
 check(not con.use_recovery(sim,m,'prep',id).accepted and m.snapshot()==before and sim.hero.hp==10,'preparation is not recovery-safe even if model safe')
 sim.phase='combat'
 check(not con.use_recovery(sim,m,'combat',id).accepted and m.snapshot()==before and sim.hero.hp==10,'combat use rejection is atomic')
 sim.phase='victory';cmd(m,'context',{'phase':'combat'});before=m.snapshot()
 check(not con.use_recovery(sim,m,'split',id).accepted and m.snapshot()==before,'sim/model phase disagreement rejects')
 cmd(m,'context',{'phase':'safe'})
 for i in range(2):
  id=uid(m,'special_tonic');var out=con.use_recovery(sim,m,'special-%d'%i,id)
  check(out.accepted and sim.hero.hp==10+72*(i+1) and sim.hero.cooldowns.q==4,'special heal actual HP with preserved CD '+str(i))
 var hp=sim.hero.hp;before=m.snapshot();id=uid(m,'special_tonic')
 var cap=con.use_recovery(sim,m,'third',id)
 check(not cap.accepted and cap.reason=='special_cap' and sim.hero.hp==hp and m.snapshot()==before,'third special atomically rejected below full HP')
 var victim=m.snapshot().inventory[0].uid
 var saved=con.receipts['special-0'].uid
 con.use_recovery(sim,m,'special-0',saved)
 check(m.snapshot()==before and sim.hero.hp==hp,'old successful use replay cannot heal again')
 check(not Consumer.new().use_recovery(sim,m,'special-0',saved).accepted and m.snapshot()==before and sim.hero.hp==hp,'coordinator replacement cannot replay consumed model receipt')
 # Actual same-room retry must not reset the recovery counter.
 sim.phase='combat';cmd(m,'context',{'phase':'combat'});sim.hero.self_rescue_used=true;sim.damage_hero(10000)
 check(sim.phase=='true_dead','retry fixture actually reached true death')
 r.retry_room()
 check(m.snapshot().special_uses==2 and m.snapshot().inventory.size()==1,'F5 coordinator retry keeps special count and inventory')
 # Finish the same roster via actual simulation, then start a new room.
 for e in sim.enemies:sim.damage_enemy(e,100000,'qa_fixture',1)
 sim.step(.05);r.start_room()
 check(m.snapshot().special_uses==0 and m.snapshot().inventory.size()==1,'actual new room resets uses without replenishing inventory')
 for e in sim.enemies:sim.damage_enemy(e,100000,'qa_fixture',2)
 sim.step(.05);sim.hero.hp=10
 var failed_again=con.use_recovery(sim,m,'third',victim)
 check(not failed_again.accepted and sim.hero.hp==10,'failed cap request replay stays failed after new room')
 check(con.use_recovery(sim,m,'new-room',victim).accepted and sim.hero.hp==82 and m.snapshot().special_uses==1,'new request after real room transition can heal')
 r.queue_free()
 r=fresh();m=r.ledger.model;sim=r.simulation;con=r.consumers
 for i in range(5):cmd(m,'buy',{'item':'normal_tonic'})
 check(m.snapshot().inventory.size()==1 and m.snapshot().inventory[0].count==5,'five normals use one slot')
 before=m.snapshot();check(not cmd(m,'buy',{'item':'normal_tonic'}).accepted and m.snapshot()==before,'sixth normal atomically rejected')
 check(not cmd(m,'buy',{'item':'special_tonic'}).accepted and m.snapshot()==before,'holding normal rejects special purchase')
 id=uid(m,'normal_tonic');con.use_recovery(sim,m,'normal-first',id);cmd(m,'sell',{'uid':id});cmd(m,'buy',{'item':'special_tonic'});before=m.snapshot();hp=sim.hero.hp
 var switched=con.use_recovery(sim,m,'switch',uid(m,'special_tonic'))
 check(not switched.accepted and switched.reason=='recovery_mutex' and m.snapshot()==before and sim.hero.hp==hp,'selling remaining normals cannot evade same-room use mutex')
 r.queue_free()
 r=fresh();m=r.ledger.model;sim=r.simulation;con=r.consumers;sim.hero.hp=71
 var all_ok=true
 for i in range(12):
  cmd(m,'buy',{'item':'blood_crystal'});r._sync_growth_to_combat()
  all_ok=all_ok and sim.hero.hp==71 and sim.hero.stats.max_hp==340 and sim.hero.cooldowns.q==4
  cmd(m,'sell',{'uid':uid(m,'blood_crystal')});r._sync_growth_to_combat()
  all_ok=all_ok and sim.hero.hp==71 and sim.hero.stats.max_hp==240 and sim.hero.cooldowns.q==4
  cmd(m,'undo_shop');r._sync_growth_to_combat()
  all_ok=all_ok and sim.hero.hp==71 and sim.hero.stats.max_hp==340 and sim.hero.cooldowns.q==4
  cmd(m,'undo_shop');r._sync_growth_to_combat()
 check(all_ok,'repeated HP buy sell undo cycles cannot heal or refresh active CD')
 cmd(m,'learn',{'slot':'Q','candidate':'Q1','expected_rank':0});r._sync_growth_to_combat()
 cmd(m,'context',{'phase':'safe','training':true})
 var reset=cmd(m,'respec');r._growth_completed({},reset)
 check(reset.accepted and sim.hero.hp==71 and sim.hero.cooldowns.q==4 and m.snapshot().skills.Q.rank==0,'training respec of learned skill cannot restore HP or current CD')
 for i in range(6):cmd(m,'buy',{'item':'mainspring'})
 before=m.snapshot();r._sync_growth_to_combat()
 check(sim.hero.attack_speed()==2.5 and sim.hero.cooldowns.q==4,'actual attack speed clamps with six components without CD reset')
 check(not cmd(m,'buy',{'item':'special_tonic'}).accepted and m.snapshot()==before,'six equipped slots reject potion atomically')
 var dependent=[];var enabled=[]
 for key in m.config.hexes:
  var entry=m.config.hexes[key]
  if not entry.get('requires','').is_empty():dependent.append({'id':key,'support':m.support(entry).supported})
  if m.support(entry).supported:enabled.append(key)
 check(dependent.all(func(x):return not x.support) and enabled.size()==7,'only seven unconditional hexes open; no fake dormant dependency consumer',{'enabled':enabled,'dependent':dependent})
 r.queue_free();await process_frame
 var report={'sha':'c1b20bc8da414452c113936b26ce9a4874bb733d','input':'headless actual integration classes with explicit gold/HP/damage fixtures, NOT OS input','checks':checks,'failures':checks.filter(func(c):return not c.passed)}
 var f=FileAccess.open('/workspace/shuabao-qa/tests/qa/round7_boundaries.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close();print(JSON.stringify(report));quit(1 if not report.failures.is_empty() else 0)
