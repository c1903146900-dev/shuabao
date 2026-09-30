extends SceneTree
const Sim = preload('res://scripts/combat/combat_sim.gd')
var failures=[]
func check(ok, label, data={}):
 print(JSON.stringify({'check':label,'passed':ok,'data':data}))
 if not ok: failures.append(label)
func fixture():
 var s=Sim.new()
 s.hero.position=Vector3.ZERO
 s.ai_enabled=false
 s.auto_finish=false
 s.hero.stats.regen=0
 return s
func _initialize():
 var s=fixture()
 for i in range(5): s.spawn_enemy('minion',Vector3((i-2)*0.2,0,-2),1)
 s.request_action('q',Vector3(0,0,-5),'qa-q1')
 s.step(.25)
 var kills=s.event_log.filter(func(e):return e.kind=='kill')
 check(kills.size()==5 and s.hero.q1_stacks==1 and s.hero.cooldowns.q==0,'Q1 five kills are one stack',{'kills':kills.size(),'stack':s.hero.q1_stacks})
 for e in s.enemies: s.damage_enemy(e,999,'qa-duplicate',1,true)
 check(s.event_log.filter(func(e):return e.kind=='kill').size()==5,'dead target cannot repeat kill')
 s.free()
 s=fixture();s.configure_test_loadout({'q':'q2'})
 for i in range(6):s.spawn_enemy('minion',Vector3(i*.5,0,-2),1000)
 s.request_action('q',Vector3(0,0,-2))
 var hp=s.hero.hp
 for i in range(159):
  s.damage_hero(1000,Vector3.ZERO,10)
  s.step(.005)
 check(s.hero.hp==hp and not s.hero.dead,'Q2 immune throughout first 0.795s')
 s.step(.01)
 check(s.event_log.filter(func(e):return e.kind=='q2_hit').size()==4 and not s.hero.untargetable,'Q2 ends at four unique hits')
 s.free()
 s=fixture();s.spawn_enemy('minion',Vector3(0,0,-2),1000);s.request_action('e');s.step(2)
 var before=s.snapshot();s.end_encounter('victory');s.step(60);var after=s.snapshot()
 check(before.hero.hp==after.hero.hp and before.hero.overload_left==after.hero.overload_left and before.hero.cooldowns==after.hero.cooldowns,'E3 state freezes during 60s safe wait')
 s.begin_encounter('qa-room-2',[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}]);s.step(5)
 check(s.hero.overload_left==0 and is_equal_approx(s.hero.cooldowns.e,32),'E3 resumes remaining 5s then starts CD',{'e_cd':s.hero.cooldowns.e})
 s.free()
 s=fixture();s.configure_test_loadout({'passive':'p2'});s.hero.self_rescue_used=true;s.damage_hero(99999)
 check(s.hero.dead and s.hero.death_state=='true_dead' and s.hero.cooldowns.passive==0,'P2 direct lethal cannot rescue')
 s.free()
 s=fixture();s.spawn_enemy('minion',Vector3(0,0,-2),1000);s.request_action('r');s.step(.1);s.end_encounter('victory');var cd=s.hero.cooldowns.r;s.step(60)
 check(s.clock.scale_factor()==1 and s.clock.presenters.is_empty() and cd==s.hero.cooldowns.r,'R1 room end restores speed and freezes CD')
 s.free()
 s=fixture();s.configure_test_loadout({'r':'r2'});s.spawn_enemy('boss',Vector3(0,0,-2),100000)
 s.request_action('r',Vector3(0,0,-2));s.step(.26)
 for i in range(2):
  s.request_action('attack',Vector3(0,0,-2));s.step(.6)
 s.request_action('r',Vector3(0,0,-2));s.step(.26)
 s.request_action('attack',Vector3(0,0,-2));s.step(.6)
 s.request_action('r',Vector3(0,0,-2));s.step(.26)
 var nails=[]
 for event in s.event_log:
  if event.kind=='r2_throw':nails.append(event.nails)
 check(nails==[1,3,4],'R2 cumulative attacks survive second throw',{'nails':nails})
 check(s.hero.cooldowns.r>129 and s.clock.scale_factor()==1,'third R2 presentation restores speed then starts CD')
 s.free()
 print('INDEPENDENT_FAILURES=',failures)
 quit(0 if failures.is_empty() else 1)
