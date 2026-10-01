extends SceneTree
const Sim=preload('res://scripts/combat/combat_sim.gd')
var rows=[]
func make(preset):
 var s=Sim.new();s.configure_test_loadout(preset);s.ai_enabled=false;s.hero.position=Vector3.ZERO;s.hero.stats.regen=0
 return s
func sane(s):
 if not is_finite(s.hero.hp) or s.hero.hp<0 or not s.hero.position.is_finite():return false
 for v in s.hero.cooldowns.values():
  if not is_finite(v) or v<0:return false
 for e in s.enemies:
  if not is_finite(e.hp) or e.hp<0:return false
 return true
func _initialize():
 for q in ['q2']:
  for e in ['e1']:
   for r in ['r1','r2']:
    for p in ['p1','p2','p3']:run_combo({'q':q,'e':e,'r':r,'passive':p})
 var failures=[]
 for row in rows:
  for key in row.checks:
   if not row.checks[key]:failures.append({'combo':row.combo,'check':key})
 var out={'sha':'50f6bf3c8df264da80edc5b4f1262e7a49942ab1','input':'actual simulation API with rank1 loadout/HP/enemy/AI fixtures; not OS play','rank_scope':'all candidates at rank1; R higher gates remain unresolved','policies':'data/combat/ability_tuning.gd POLICIES; docs/COMBAT_PROGRESS.md retained E1/E2/E3/R2 states respected','rows':rows,'failures':failures}
 var f=FileAccess.open('/workspace/shuabao-qa/tests/qa/round10_six.json',FileAccess.WRITE);f.store_string(JSON.stringify(out,'  '));f.close();print(JSON.stringify({'combos':rows.size(),'failures':failures}));quit(1 if not failures.is_empty() else 0)
func run_combo(preset):
 var row={'combo':preset,'checks':{},'boundary':[]};var s=make(preset);s.auto_finish=false
 s.spawn_enemy('boss',Vector3(0,0,-1),100000)
 s.spawn_enemy('minion',Vector3(1,0,-2),100000)
 s.hero.hp=25;s.damage_hero(2)
 var accepted={};var finite=true
 for i in range(160):
  var action=['e','q','r','attack','shift'][i%5]
  var result=s.request_action(action,Vector3(0,0,-1))
  if result.accepted:accepted[action]=true
  s.step(.1);finite=finite and sane(s)
 # Exercise actual kill attribution/passive progress without allowing a fixture-room win.
 for i in range(10):
  var target=s.spawn_enemy('minion',s.hero.position,1)
  s.damage_enemy(target,10,'attack',900+i)
 row['accepted_actions']=accepted
 row['passive_events']=s.event_log.filter(func(x):return x.kind in ['low_health_passive','permanent_ad_gained'])
 row.checks.finite_nonnegative_through_interleaving=finite
 s.step(150)
 row.checks.no_permanent_action_lock=not s.extensions.blocks_actions() and not s.r1_active and s.hero.lock_time==0 and s.hero.dash_left==0 and s.hero.overload_left==0 and s.clock.presenters.is_empty() and s.clock.scale_factor()==1 and sane(s)
 row.checks.all_active_slots_exercised=accepted.has('q') and accepted.has('e') and accepted.has('r')
 s.free()
 for order in [['e','q','r'],['e','r','q']]:
  s=make(preset);var target=s.spawn_enemy('minion',Vector3(0,0,-1),1)
  var requests=[]
  for action in order:requests.append(s.request_action(action,target.position))
  s.step(1.5)
  var ended=s.snapshot();var was_victory=s.phase=='victory'
  var next=s.begin_encounter('next-'+str(order),[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}])
  s.step(1.0)
  var after=s.snapshot();var hp=s.enemies[0].hp
  var label='no_old_damage_'+str(order)
  row.checks[label]=was_victory and next.accepted and hp==1000
  row.boundary.append({'order':order,'requests':requests,'ended':ended,'after':after,'events':s.event_log.duplicate(true)})
  s.step(20)
  row.checks['retained_effects_eventually_finish_'+str(order)]=not s.extensions.blocks_actions() and not s.r1_active and sane(s)
  s.free()
 if preset.r=='r2':
  s=make(preset);s.auto_finish=false;s.spawn_enemy('boss',Vector3(0,0,-1),100000)
  s.request_action('r',Vector3(0,0,-1));s.step(.3)
  s.request_action('attack',Vector3(0,0,-1));s.step(.6)
  s.request_action('r',Vector3(0,0,-1));s.step(.3)
  s.request_action('attack',Vector3(0,0,-1));s.step(.6)
  s.request_action('r',Vector3(0,0,-1));s.step(.3)
  var throws=s.event_log.filter(func(x):return x.kind=='r2_throw')
  row['r2_throws']=throws
  row.checks.r2_count_stays_cumulative=throws.size()==3 and throws[0].nails==1 and throws[1].nails==2 and throws[2].nails==3 and throws[2].attacks==2 and s.hero.cooldowns.r>129
  s.free()
 s=make(preset);s.auto_finish=false;s.spawn_enemy('boss',Vector3(0,0,-1),100000)
 s.request_action('r',Vector3(0,0,-1));var hp_before=s.hero.hp;s.damage_hero(100000)
 row.checks.ultimate_presentation_blocks_damage=s.hero.hp==hp_before
 s.end_encounter('true_dead') # Forced external lifecycle event, not a real lethal while immune.
 row.checks.forced_terminal_clears_slow=s.clock.presenters.is_empty() and s.clock.scale_factor()==1 and not s.r1_active
 s.free()
 s=make(preset);s.auto_finish=false;s.spawn_enemy('boss',Vector3(0,0,-1),100000)
 s.request_action('r',Vector3(0,0,-1));s.step(1.2);s.hero.self_rescue_used=true;s.damage_hero(100000)
 row.checks.actual_lethal_after_show_clears_slow=s.phase=='true_dead' and s.hero.dead and s.clock.presenters.is_empty() and s.clock.scale_factor()==1
 var frozen=s.hero.snapshot();var time=s.clock.world_time;s.step(60)
 row.checks.death_freezes_hp_cd_clock=s.hero.snapshot()==frozen and s.clock.world_time==time
 s.free();rows.append(row)
