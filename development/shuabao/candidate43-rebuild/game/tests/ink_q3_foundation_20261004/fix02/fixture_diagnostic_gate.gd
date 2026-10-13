extends SceneTree
## Execute the exact formerly mistaken fixture to observe its real refusal.
## No game mechanic, range, CD, movement, or transaction guard is patched.
const Sim=preload("res://tests/ink_q3_foundation_20261004/fix01/ink_q3_sim.gd")
const InputAdapter=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
var checks:int=0
var failures:Array=[]
var completed:Array=[]
var evidence:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func fresh():
 var sim=Sim.new();root.add_child(sim);sim.auto_finish=false;sim.ai_enabled=false
 sim.hero.position=Vector3.ZERO;sim.hero.loadout.q="q3";sim.hero.ranks.q=1
 sim.hero.stats.ap=100.0;sim.hero.stats.crit_chance=0.0
 check(sim.begin_encounter("q3-fixture-diagnostic",[]).accepted,"real room begins")
 sim.set_hexes([]);return sim
func stop_walk(sim)->Dictionary:
 var adapter=InputAdapter.new();adapter.bind(sim)
 var event=InputEventKey.new();event.physical_keycode=KEY_D;event.pressed=false
 return adapter.handle_event(event)
func run()->void:
 var sim=fresh()
 check(sim.request_action("q",Vector3(4,0,0)).accepted,"original first raise succeeds")
 sim.paused=true;sim.step(8);sim.paused=false
 sim.move_during_hitstop(.1,Vector3.RIGHT);sim.step(4.98);sim.step(.02)
 sim.common_reset_cooldowns(["q"])
 var attempted:Vector3=Vector3(4,0,0)
 var before:Dictionary={"hero_position":sim.hero.position,"move_intent":sim.hero.move_intent,"target":attempted,"distance":sim.hero.position.distance_to(attempted),"range":sim.v("Q3-1",1),"cooldown_q":sim.hero.cooldowns.q,"phase":sim.phase,"hero_time":sim.hero_time,"transaction_active":sim.transaction_active}
 var rejection:Dictionary=sim.request_action("q",attempted)
 check(before.move_intent==Vector3.RIGHT and before.distance>before.range,"old fixture actually keeps walking outside range")
 check(before.cooldown_q==0,"old fixture genuine CD reset already reached zero")
 check(not rejection.accepted and rejection.reason=="outside_placement_range","actual first post-expiry rejection is range, not cooldown")
 var keyup:Dictionary=stop_walk(sim)
 check(keyup.accepted and sim.hero.move_intent==Vector3.ZERO,"real D key-up stops ongoing intent")
 var legal_target:Vector3=sim.hero.position-Vector3(4,0,0)
 var valid:Dictionary=sim.request_action("q",legal_target)
 check(valid.accepted,"same sim accepts source-legal target after legitimate reset")
 evidence.persistent_walk_range={"before":before,"rejection":rejection,"keyup":keyup,"legal_target":legal_target,"legal_admission":valid}
 sim.free();completed.append("persistent_walk_range")
 var rows:Array=[]
 for trigger in ["ink_q3_raised","damage","ink_q3_collapse_started"]:
  sim=fresh();var enemy:Dictionary=sim.spawn_enemy("minion",Vector3(4,0,0),100000.0);enemy.state="chase";enemy.defence=0.0
  var captured:Array=[]
  sim.combat_event.connect(func(event):
   if captured.is_empty() and event.kind==trigger:
    captured.append({"event_kind":event.kind,"transaction_active":sim.transaction_active})
    sim.end_encounter("cancelled")
    captured[0]["inside_begin"]=sim.begin_encounter("callback-new-room",[]))
  var first:Dictionary=sim.request_action("q",Vector3(4,0,0))
  var second:Dictionary={}
  if trigger=="ink_q3_collapse_started":second=sim.request_action("q",Vector3(12,0,0))
  check(first.accepted and captured.size()==1,"real source callback fires once "+trigger)
  if captured.size()==1:check(captured[0].transaction_active and not captured[0].inside_begin.accepted and captured[0].inside_begin.reason=="invalid_phase","actual reentrant begin obeys existing transaction guard "+trigger)
  check(not sim.transaction_active and sim.phase=="cancelled" and sim.ink_mountain.is_empty(),"old action returns with cancelled terrain and no live transaction "+trigger)
  var after:Dictionary=sim.begin_encounter("callback-new-room",[])
  check(after.accepted and sim.room_id=="callback-new-room" and sim.ink_q3_receipts.is_empty(),"normal next room succeeds after action returns "+trigger)
  rows.append({"trigger":trigger,"first":first,"second":second,"callback":captured,"after_action":after});sim.free()
 evidence.callback_transaction_guard=rows;completed.append("callback_transaction_guard")
 var report:Dictionary={"suite":"q3_fix02_real_fixture_diagnostics","passed":failures.is_empty(),"checks":checks,"failures":failures,"completed":completed,"evidence":evidence,"source_binding_id":FileAccess.get_sha256("res://tests/ink_q3_foundation_20261004/fix02/source_binding.json"),"scope":"actual refusal and legal fixture recovery only; same unmodified fix01 mechanic Sim"}
 var file=FileAccess.open("res://tests/ink_q3_foundation_20261004/fix02/fixture_diagnostic_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("INK_Q3_FIXTURE_DIAGNOSTIC_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
