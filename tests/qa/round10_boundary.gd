extends SceneTree
const Sim=preload('res://scripts/combat/combat_sim.gd')
var rows=[]
func fresh(preset):
 var s=Sim.new();s.configure_test_loadout(preset);s.ai_enabled=false;s.hero.position=Vector3.ZERO
 return s
func check(label,ok,evidence):rows.append({'name':label,'pass':ok,'evidence':evidence})
func next(s,id):return s.begin_encounter(id,[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}])
func _initialize():
 for r in ['r1','r2']:
  for p in ['p1','p2','p3']:
   var s=fresh({'q':'q2','e':'e1','r':r,'passive':p})
   var enemy=s.spawn_enemy('minion',Vector3.FORWARD)
   var a=s.request_action('attack',enemy.position);s.step(.11)
   var before=enemy.hp
   var e=s.request_action('e',enemy.position);var q=s.request_action('q',enemy.position)
   s.step(.2);var ended=s.snapshot();var frozen=s.hero.snapshot();s.step(10)
   var frozen_ok=frozen==s.hero.snapshot()
   var accepted=next(s,'next');s.step(2)
   check('original_default64_'+r+'_'+p,a.accepted and e.accepted and q.accepted and before==32 and ended.phase=='victory' and not ended.hero.cast_state.has('q2') and not ended.hero.untargetable and ended.hero.cooldowns.q>0 and frozen_ok and accepted.accepted and s.enemies[0].hp==1000,{'ended':ended,'next':s.snapshot(),'events':s.event_log})
   s.free()
 # Close during two distinct synchronous callbacks: Q2 damage and Q2 hit.
 for event_kind in ['damage','q2_hit']:
  var s=fresh({'q':'q2'});s.auto_finish=false
  s.spawn_enemy('minion',Vector3.FORWARD,1000);s.spawn_enemy('minion',Vector3(0,0,-2),1000)
  s.combat_event.connect(func(ev):
   if ev.kind==event_kind:s.end_encounter('victory'))
  s.request_action('q',Vector3.FORWARD);s.step(.3)
  var closed=s.snapshot();next(s,'callback-next');s.step(2)
  check('q2_close_in_'+event_kind,closed.phase=='victory' and not closed.hero.cast_state.has('q2') and s.enemies[0].hp==1000,{'closed':closed,'after':s.snapshot(),'events':s.event_log})
  s.free()
 # Wrong room/generation/instance contexts must be inert even if actor IDs match.
 for ability in ['q','e']:
  for field in ['encounter_id','encounter_generation','simulation_instance']:
   var s=fresh({'q':'q2','e':'e1'});s.auto_finish=false
   s.spawn_enemy('minion',Vector3.FORWARD,1000)
   s.request_action(ability,Vector3.FORWARD)
   var state=s.hero.cast_state['q2' if ability=='q' else 'e1']
   state[field]='stale' if field=='encounter_id' else -123
   s.hero.position=Vector3(4,0,4);var position=s.hero.position
   s.step(.5)
   check('stale_'+ability+'_'+field,s.enemies[0].hp==1000 and s.hero.position==position and not s.hero.cast_state.has('q2' if ability=='q' else 'e1'),{'state':s.snapshot(),'events':s.event_log})
   s.free()
 # Natural E1 marked state and projectile state both cleared on enemy roster replacement.
 for marked in [false,true]:
  var s=fresh({'e':'e1'});s.auto_finish=false
  s.spawn_enemy('minion',Vector3.FORWARD if marked else Vector3(0,0,-8),1000)
  s.request_action('e',s.enemies[0].position)
  if marked:s.step(.1)
  var old=s.hero.cast_state.e1.duplicate(true)
  s.end_encounter('victory');next(s,'e1-next');var cleared=not s.hero.cast_state.has('e1')
  old.target=s.enemies[0].actor_id;s.hero.cast_state.e1=old;s.step(.5)
  check('e1_recycled_target_'+str(marked),cleared and s.enemies[0].hp==1000 and not s.hero.cast_state.has('e1'),{'old':old,'after':s.snapshot(),'events':s.event_log})
  s.free()
 var s=fresh({'r':'r2'});s.auto_finish=false;s.spawn_enemy('minion',Vector3.FORWARD,1000)
 s.request_action('r',Vector3.FORWARD);s.step(.3);s.request_action('attack',Vector3.FORWARD)
 var pending=s.pending[0].duplicate(true)
 s.end_encounter('victory');next(s,'r2-next');s.step(.4)
 var before=s.hero.cast_state.r2.attacks
 s.extensions.on_basic_attack_completed(pending)
 var old_ignored=s.hero.cast_state.r2.attacks==before
 s.step(s.hero.cooldowns.attack+.01)
 var current=s.request_action('attack',s.enemies[0].position);s.step(.15)
 var counted=s.hero.cast_state.r2.attacks
 s.extensions.on_basic_attack_completed(pending)
 check('r2_old_callback_new_real_attack',current.accepted and old_ignored and counted==before+1 and s.hero.cast_state.r2.attacks==counted,{'new_attack':current,'old_callback':pending,'after':s.snapshot(),'events':s.event_log})
 s.free()
 var failures=rows.filter(func(row):return not row.pass)
 var f=FileAccess.open('/workspace/shuabao-qa/tests/qa/round10_boundary.json',FileAccess.WRITE)
 f.store_string(JSON.stringify({'sha':'50f6bf3c8df264da80edc5b4f1262e7a49942ab1','scope':'independent controlled simulation; no OS or package claim','rows':rows,'failures':failures},'  '));f.close()
 print(JSON.stringify({'checks':rows.size(),'failures':failures.map(func(row):return row.name)}));quit(0 if failures.is_empty() else 1)
