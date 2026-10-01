extends SceneTree
const Sim=preload('res://scripts/combat/combat_sim.gd')
var results=[]
func fixture(preset={}):
 var s=Sim.new()
 s.hero.position=Vector3.ZERO;s.hero.stats.regen=0;s.ai_enabled=false;s.auto_finish=false
 if not preset.is_empty():s.configure_test_loadout(preset)
 return s
func record(label,ok,data={}):
 var r={'check':label,'passed':ok,'data':data};results.append(r);print(JSON.stringify(r))
func _initialize():
 for replacement in [false,true]:
  var s=fixture({'q':'q2'})
  var first=s.spawn_enemy('minion',Vector3(0,0,-2),1000)
  if replacement:s.spawn_enemy('minion',Vector3(1,0,-2),1000)
  s.request_action('q',first.position)
  s.step(.1);s.damage_enemy(first,2000,'external_fixture',90,true);s.step(.11)
  var hits=s.event_log.filter(func(e):return e.kind=='q2_hit')
  record('Q2 lost initial target replacement='+str(replacement),hits.size()==(1 if replacement else 0) and not s.hero.cast_state.has('q2') and not s.hero.untargetable and s.hero.cooldowns.q>11.9,{'hits':hits,'cd':s.hero.cooldowns.q})
  s.free()
 var s=fixture({'q':'q2'});s.spawn_enemy('minion',Vector3(0,0,-2),1000);var next=s.spawn_enemy('minion',Vector3(1,0,-2),1000)
 s.request_action('q',Vector3(0,0,-2));s.step(.21);s.damage_enemy(next,2000,'external_fixture',91,true);s.step(.2)
 record('Q2 next target dies after first hit',s.event_log.filter(func(e):return e.kind=='q2_hit').size()==1 and not s.hero.cast_state.has('q2') and not s.hero.untargetable)
 s.free()
 s=fixture({'e':'e3','passive':'p2'});s.request_action('e');s.step(2);s.hero.hp=24;s.damage_hero(1)
 var remaining=s.hero.overload_left
 var recast=s.request_action('e')
 record('P2 active E3 gives reset credit without restarting duration',is_equal_approx(remaining,5) and s.hero.cast_state.get('e_reset_credit',false) and not recast.accepted and s.hero.hp>24,{'remaining':remaining,'recast':recast})
 s.end_encounter('victory');s.step(60);s.begin_encounter('second',[{'kind':'minion','position':Vector3(10,0,10),'hp':1000}]);s.step(5)
 record('P2 E3 credit survives freeze and skips one end cooldown',s.hero.overload_left==0 and s.hero.cooldowns.e==0 and not s.hero.cast_state.has('e_reset_credit'))
 s.request_action('e');s.step(7)
 record('P2 E3 credit cannot be spent twice',is_equal_approx(s.hero.cooldowns.e,32))
 s.free()
 for kind in ['r1','r2']:
  s=fixture({'r':kind});s.spawn_enemy('boss',Vector3(0,0,-2),100000);s.request_action('r',Vector3(0,0,-2));s.damage_hero(999999)
  record(kind+' enemy lethal during presentation is blocked',not s.hero.dead)
  s.end_encounter('true_dead') # lifecycle cancellation, not a claimed player death
  record(kind+' lifecycle termination clears slow tokens',s.clock.presenters.is_empty() and s.clock.scale_factor()==1)
  s.free()
  s=fixture({'r':kind});s.spawn_enemy('boss',Vector3(0,0,-2),100000);s.request_action('r',Vector3(0,0,-2));s.step(1.1 if kind=='r1' else .26)
  s.hero.self_rescue_used=true;s.damage_hero(999999)
  record(kind+' actual lethal after presentation restores terminal clock',s.hero.dead and s.phase=='true_dead' and s.clock.scale_factor()==1 and s.clock.presenters.is_empty())
  s.free()
 # Natural victory before delayed R1 impact: independently cast E1 projectile kills last foe.
 s=fixture({'e':'e1','r':'r1'});s.auto_finish=true
 var foe=s.spawn_enemy('minion',Vector3(0,0,-1),1)
 s.request_action('e',foe.position);s.request_action('r',foe.position);s.step(.2)
 var ended={'phase':s.phase,'r1_active':s.r1_active,'scale':s.clock.scale_factor(),'pending':s.pending.duplicate(true),'r_cd':s.hero.cooldowns.r,'world_time':s.clock.world_time}
 s.begin_encounter('after-natural-victory',[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}]);s.step(.05)
 var actual=s.enemies[0].hp
 record('Ended R1 cannot strike next room without input',actual==1000,{'ended':ended,'next_room_hp':actual,'events':s.event_log})
 s.free()
 var f=FileAccess.open(OS.get_environment('QA_COMBAT_REPORT') if not OS.get_environment('QA_COMBAT_REPORT').is_empty() else 'res://tests/qa/round2_combat.json',FileAccess.WRITE);f.store_string(JSON.stringify(results,'  '));f.close()
 quit(1 if results.any(func(r):return not r.passed) else 0)
