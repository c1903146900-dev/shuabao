extends SceneTree
## Bounded source G22 regression: two real contacts in one area segment, first
## enemy truly dies; existing live-set/stat pipeline changes before target two.
const Before=preload("res://tests/ink_q3_foundation_20261004/fix01/ink_q3_sim.gd")
const Fixed=preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
var checks:int=0
var failures:Array=[]
var completed:Array=[]
var evidence:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a:float,b:float,label:String)->void:check(absf(a-b)<.00001,"%s %.9f expected %.9f"%[label,a,b])
func fresh(fixed:bool):
 var sim=Fixed.new() if fixed else Before.new();root.add_child(sim)
 sim.auto_finish=false;sim.ai_enabled=false;sim.hero.position=Vector3.ZERO
 sim.hero.loadout.q="q3";sim.hero.ranks.q=1;sim.hero.stats.ap=100.0
 sim.hero.stats.crit_chance=0;sim.hero.stats.regen=0
 check(sim.begin_encounter("g22-q3-batch",[]).accepted,"G22 fixture genuine room")
 sim.set_hexes(["common_g22"]);sim.damage_hero(100,Vector3.ZERO,0,true)
 return sim
func target(sim,at:Vector3,kind:String,hp:float,defence:float=0)->Dictionary:
 var enemy:Dictionary=sim.spawn_enemy(kind,at,hp);enemy.state="chase";enemy.defence=defence;enemy.radius=.25;return enemy
func run()->void:
 for segment in ["raise","collapse"]:
  for transition in ["none_to_duel","horde_to_none"]:
   var key:String=segment+"_"+transition
   var old:Dictionary=scenario(false,segment,transition)
   var fixed:Dictionary=scenario(true,segment,transition)
   check(absf(float(old.second_damage)-float(fixed.second_damage))>.01,key+" old behavior demonstrably differs after first kill")
   evidence[key]={"preserved_fix01":old,"fixed":fixed};completed.append(key)
 var report:Dictionary={"suite":"q3_same_time_G22_batch_snapshot","passed":failures.is_empty(),"checks":checks,"failures":failures,"completed":completed,"evidence":evidence,"source_binding_id":FileAccess.get_sha256("res://tests/ink_q3_foundation_20261004/fix02/source_binding.json"),"scope":"Q3 raise/collapse G22 same-time mode, penetration and lifesteal only; not all common-Hex acceptance"}
 var file=FileAccess.open("res://tests/ink_q3_foundation_20261004/fix02/g22_batch_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("INK_Q3_G22_BATCH_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func scenario(fixed:bool,segment:String,transition:String)->Dictionary:
 var sim=fresh(fixed)
 if segment=="collapse":check(sim.request_action("q",Vector3(4,0,0)).accepted,"empty original raise before independent collapse")
 var a:Vector3=Vector3(4,0,0) if segment=="raise" else Vector3(7,0,0)
 var b:Vector3=Vector3(4,0,1) if segment=="raise" else Vector3(9,0,0)
 var first:Dictionary=target(sim,a,"minion",1.0)
 var second:Dictionary=target(sim,b,"elite" if transition=="none_to_duel" else "minion",100000.0,100.0 if transition=="none_to_duel" else 0.0)
 if transition=="horde_to_none":
  for i in range(int(sim.common.runtime.parameter("g22",1))-2):target(sim,Vector3(18,0,12+i*.5),"minion",100000.0)
 var before:float=second.hp;var health_before:float=sim.hero.hp
 var released:Dictionary=sim.request_action("q",Vector3(4,0,0) if segment=="raise" else Vector3(12,0,0))
 check(released.accepted and first.dead,"actual first contact kills first ordinary enemy")
 var damage:float=before-second.hp;var healing:float=sim.hero.hp-health_before
 var nominal:float=50.0 if segment=="raise" else 195.0
 var expected:float=nominal*.5 if transition=="none_to_duel" else nominal*1.25
 if fixed:
  near(damage,expected,segment+" simultaneous second contact retains initial mode and penetration")
  near(healing,0.0 if transition=="none_to_duel" else (1.0+expected)*.06*.4,segment+" simultaneous second contact retains initial lifesteal")
 else:
  near(damage,nominal*1.2*100.0/180.0 if transition=="none_to_duel" else nominal,segment+" original demonstrates mid-batch mode change")
  near(healing,0.0 if transition=="none_to_duel" else 1.0*.06*.4,segment+" original demonstrates lost mid-batch lifesteal")
 # An independent later segment must recompute from the now-real live set.
 before=second.hp;health_before=sim.hero.hp
 if segment=="raise":
  check(sim.request_action("q",Vector3(12,0,0)).accepted,"independent subsequent collapse uses same root")
  nominal=195.0
 else:
  sim.common_reset_cooldowns(["q"]);check(sim.hero.cooldowns.q==0,"real CD reset before independent next raise")
  check(sim.request_action("q",b).accepted,"independent next raise after completed root")
  nominal=50.0
 var subsequent:float=before-second.hp
 near(subsequent,nominal*1.2*100.0/180.0 if transition=="none_to_duel" else nominal,segment+" subsequent independent segment re-evaluates actual live set")
 near(sim.hero.hp-health_before,0,segment+" subsequent independent segment no longer retains horde lifesteal")
 var row:Dictionary={"first_dead":first.dead,"second_damage":damage,"batch_heal":healing,"later_damage":subsequent,"remaining_live":sim.living().size(),"original_segment":segment,"transition":transition}
 sim.free();return row
