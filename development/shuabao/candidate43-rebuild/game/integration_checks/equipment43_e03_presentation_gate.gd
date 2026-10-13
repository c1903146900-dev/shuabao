extends "res://integration_checks/equipment43_source_gate.gd"
## Original route earns Lv6/SP before original R1 input. Source preparation
## defeats only entered authored enemies; no level/rank/AI/clock assignment.
func _initialize() -> void:
 output_path="user://equipment43_e03_presentation.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func e03_reach_r_room(f: Dictionary) -> bool:
 var learned: bool=false
 for row: int in range(1,12):
  var at: float=e03_now(f)
  if not enter(f,row):return false
  if f.session.status=="service":
   if not check(f.session.complete_service().get("accepted",false),"actual R preparation service completes"):return false
  else:
   f.e03_combat_start=at
   if learned:
    if not spawn_ready(f):return false
    e03_records.append({"kind":"earned_R_room","row":row,"node":B01_ROUTE[row-1],"level":f.session.ledger.model.state.level,"points":f.session.ledger.model.state.points,"rank":f.sim.hero.ranks.r,"run_clock":e03_now(f),"combat_start":at,"natural_leveling":false,"original_rewards":true})
    return check(f.sim.hero.loadout.r=="r1" and f.sim.hero.ranks.r==1,"original earned R1 rank projects into current sameactor")
   if not b04_settle_row(f,row):return false
  if not learned and int(f.session.ledger.model.state.level)>=6:
   if not choose_required_hexes(f):return false
   var paid: Dictionary=command(f,"learn",{"slot":"R","candidate":"R1","expected_rank":0})
   if not check(paid.get("accepted",false),"original earned Lv6 andSP legally learn R1"):return false
   learned=true
 return check(false,"original bounded route has a combat after legitimateR learning")

func run() -> void:
 g03_reset_evidence()
 current_group="real_R1_presentation_clock"
 e03_required=[current_group];e03_completed=[];e03_partition=current_group
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():e03_report();return
 if not buy(f,E03_ITEM) or not buy(f,"base:B12") or not check(f.session.close_panel().get("accepted",false),"R preparation shopcloses") or not e03_reach_r_room(f):dispose(f);e03_report();return
 if b04_keep_original(f).is_empty() or not e03_damage_deficit(f,200.0,"R clockmissingHP") or not e03_until(f,5.85,"preR sixsecondapproach"):dispose(f);e03_report();return
 if not check(not e03_view(f).active and e03_now(f)-float(f.e03_combat_start)<6.0,"real R1 begins before E03 sixsecondthreshold"):dispose(f);e03_report();return
 var aim: Vector3=f.sim.hero.position
 var rdown:=InputEventKey.new();rdown.physical_keycode=KEY_R;rdown.pressed=true
 var rup:=InputEventKey.new();rup.physical_keycode=KEY_R;rup.pressed=false
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
 var armed: Dictionary=f.router.handle_event(rdown,aim)
 f.router.handle_event(rup,aim)
 var committed: Dictionary=f.router.handle_event(down,aim)
 f.router.handle_event(up,aim)
 if not check(armed.get("accepted",false) and committed.get("accepted",false),"actual R-down and fresh LMB commit original learnedR1"):dispose(f);e03_report();return
 if not check(f.sim.clock.domain.snapshot().presentations.has(f.sim.hero.actor_id),"original R1 opens original shortpresentation clock"):dispose(f);e03_report();return
 var slows: Array=[]
 for index: int in range(100):
  if not f.sim.clock.domain.snapshot().presentations.has(f.sim.hero.actor_id):break
  if index==8:
   var saved: Dictionary={"clock":e03_now(f),"hp":f.sim.hero.hp,"presentation":f.sim.clock.domain.snapshot(),"view":e03_view(f)}
   check(f.session.set_modal_blocked(true).get("accepted",false),"original modal pauses R presentation")
   step(f,12)
   check(e03_now(f)==saved.clock and f.sim.hero.hp==saved.hp and f.sim.clock.domain.snapshot()==saved.presentation and e03_view(f)==saved.view,"pause freezes original world/presentation and E03 condition together")
   check(f.session.set_modal_blocked(false).get("accepted",false),"original modal resumes R presentation")
  var before: Dictionary={"world":f.sim.clock.world_time,"common":e03_now(f),"hero":f.sim.hero_time,"presenter_actor":f.sim.presentation_actor_time,"real":f.sim.real_time}
  if not e03_tick(f,"real R presentation tick"+str(index)):dispose(f);e03_report();return
  var elapsed: Dictionary={"world":float(f.sim.clock.world_time)-float(before.world),"common":e03_now(f)-float(before.common),"hero":float(f.sim.hero_time)-float(before.hero),"presenter_actor":float(f.sim.presentation_actor_time)-float(before.presenter_actor),"real":float(f.sim.real_time)-float(before.real)}
  e03_near(float(elapsed.common),float(elapsed.world),"E03 reads original buff/worldclock during ownpresentation")
  e03_near(float(elapsed.hero),float(elapsed.world),"original hero effectclock stays worldclock")
  if float(elapsed.presenter_actor)>float(elapsed.world):slows.append(elapsed)
 check(not slows.is_empty(),"actual R1 separates presenter motion time from slower gameplaytime")
 check(not f.sim.clock.domain.snapshot().presentations.has(f.sim.hero.actor_id),"original shortR1 presentation ends within authored sourcebudget")
 if not e03_until(f,6.2,"postR threshold"):dispose(f);e03_report();return
 check(e03_view(f).active,"E03 starts only after six actual originalcombat seconds")
 e03_records.append({"kind":"real_R1_clock","armed":armed,"committed":committed,"slow_slices":slows,"end_view":e03_view(f),"rank_direct_write":false,"clock_direct_write":false,"native_GUI":false})
 b04_integrity(f,current_group);dispose(f);e03_completed.append(current_group)
 e03_report()
