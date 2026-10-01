extends SceneTree
const Room=preload('res://scripts/integration/room.gd')
var checks=[]
var samples={}
func check(ok,label,data={}):checks.append({'passed':ok,'check':label,'data':data})
func _initialize():call_deferred('run_checks')
func run_checks():
 var r=Room.new();root.add_child(r);r.set_physics_process(false)
 var m=r.ledger.model
 r.start_room()
 var first=r.simulation.enemies[0]
 var event={'combat_level_id':r.simulation.combat_level_id,'target':first.actor_id}
 var before=m.snapshot()
 check(not r._credit_kill(event).accepted and m.snapshot()==before,'live enemy cannot award')
 for enemy in r.simulation.enemies:r.simulation.damage_enemy(enemy,100000,'qa_fixture',1)
 r.simulation.step(.05)
 check(r.simulation.phase=='victory','fixture reached real victory evaluation')
 var win=r.simulation.snapshot();before=m.snapshot();samples.win=before
 for i in range(20):
  for enemy in r.simulation.enemies:r._credit_kill({'combat_level_id':r.simulation.combat_level_id,'target':enemy.actor_id})
  r._encounter_finished(win)
 check(m.snapshot()==before,'replayed real kill and terminal callbacks preserve complete ledger')
 # Explicit injured/cooling fixture, separate from the OS natural route.
 r.simulation.hero.hp=71.0;r.simulation.hero.cooldowns.q=4.0
 var result=m.command('qa-buy','buy',{'item':'iron_blade'});r._growth_completed({},result)
 for i in range(20):r._sync_growth_to_combat()
 check(result.accepted and r.simulation.hero.hp==71.0 and r.simulation.hero.cooldowns.q==4.0 and r.simulation.hero.stats.ad==40.0,'AD purchase and repeat projection neither refill injured HP nor reset CD nor compound AD')
 samples.purchased=r.integration_snapshot()
 r.start_room();samples.room2=r.integration_snapshot()
 check(r.simulation.hero.hp==71.0 and r.simulation.hero.cooldowns.q==4.0 and m.snapshot().inventory==samples.purchased.growth.inventory,'next room keeps HP CD and inventory')
 before=m.snapshot();check(not r._credit_kill(event).accepted and m.snapshot()==before,'old-room reward callback rejected')
 var victim=r.simulation.enemies[0]
 r.simulation.damage_enemy(victim,100000,'qa_fixture',2)
 before=m.snapshot();r.simulation.damage_enemy(victim,100000,'qa_fixture',2)
 check(m.snapshot()==before,'second lethal delivery for dead enemy cannot credit again')
 r.simulation.damage_hero(100000);samples.downed=r.integration_snapshot()
 check(m.snapshot().xp==before.xp and m.snapshot().gold==before.gold,'first down does not deduct XP or gold')
 r._rescue();r.simulation.step(2.0);r.simulation.damage_hero(100000)
 check(r.simulation.phase=='true_dead','fixture waited through rescue immunity before lethal damage')
 var dead=r.simulation.snapshot();samples.dead=r.integration_snapshot();var penalized=m.snapshot()
 check(penalized.xp==int(floor(before.xp*.7)) and penalized.level==before.level and penalized.points==before.points and penalized.gold==before.gold,'true death only deducts current XP, preserves level points gold')
 for i in range(20):r._encounter_finished(dead)
 check(m.snapshot()==penalized,'same terminal callback cannot repeat penalty')
 var cd=r.simulation.hero.cooldowns.duplicate(true);var enemy_state=r.simulation.enemies.duplicate(true)
 r.retry_room();samples.retry=r.integration_snapshot()
 check(r.simulation.hero.hp==84.0 and r.simulation.hero.cooldowns==cd and r.simulation.enemies==enemy_state and m.snapshot().reward_ids==penalized.reward_ids,'retry keeps dead enemy, reward IDs, HP policy and cooldown')
 before=m.snapshot()
 for i in range(20):r.retry_room();r._credit_kill({'combat_level_id':r.simulation.combat_level_id,'target':victim.actor_id})
 check(m.snapshot()==before,'retry spam and credited corpse cannot farm rewards')
 # Independent full-cap reward sequence, explicitly a model fixture, not OS level18 play.
 var cap=load('res://scripts/integration/run_model.gd').new(r.ledger.definitions,'fengli')
 var rng=RandomNumberGenerator.new();rng.seed=294042
 var invariant=true
 for i in range(64):
  var grant={'event_id':'cap-%d'%i,'room':'cap-room','gold':1,'xp':rng.randi_range(1,500)}
  cap.command('cap-%d'%i,'reward_minion',grant)
  var cs=cap.snapshot()
  invariant=invariant and cs.points==cs.level and cs.level<=18 and cs.granted_level_ids.size()==cs.level
  cap.command('cap-replay-%d'%i,'reward_minion',grant)
  invariant=invariant and cs==cap.snapshot()
 check(invariant and cap.snapshot().level==18 and cap.snapshot().points==18,'random XP awards reach level18 with exactly18 points, duplicate rewards grant no extras')
 var cap_before=cap.snapshot()
 var extra=cap.command('cap-extra','reward_minion',{'event_id':'extra','gold':1,'xp':1,'points':1})
 check(not extra.accepted and cap.snapshot()==cap_before,'reward cannot smuggle an extra skill point')
 samples.level18=cap.snapshot()
 var report={'sha':'a294d0420f5b5a23027d94755a9f78509b6929b4','scope':'headless actual integration class with explicit damage/HP/CD fixtures; NOT OS gameplay','checks':checks,'samples':samples}
 var f=FileAccess.open('/workspace/shuabao-qa/tests/qa/round6_boundaries.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close()
 print(JSON.stringify({'failures':checks.filter(func(c):return not c.passed)}))
 r.queue_free();await process_frame;quit(1 if checks.any(func(c):return not c.passed) else 0)
