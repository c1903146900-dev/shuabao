extends "res://integration_checks/c03_source_gate.gd"
## Six independent legal initial skill choices. Wallet is the sole state fixture.
var c03_family: String="q1"
var c03_release_samples: Array=[]
func _initialize() -> void:
 output_path="user://c03_release_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--c03-family="):c03_family=arg.trim_prefix("--c03-family=")
 if c03_family not in ["q1","q2","q3","e1","e2","e3"]:quit(2);return
 run.call_deferred()
func prepare_initial_choices(f: Dictionary) -> bool:
 check(not f.session.open_panel().get("accepted",false),"initial mandatory Hex blocks shop")
 if not choose_required_hexes(f):return false
 var slot: String=c03_family.left(1).to_upper()
 if not check(command(f,"learn",{"slot":slot,"candidate":c03_family.to_upper(),"expected_rank":0}).get("accepted",false),"actual original initial1SP learns "+c03_family):return false
 f.session.update_after_source_step()
 return check(f.session.ledger.model.state.points==0 and str(f.sim.hero.loadout[slot.to_lower()])==c03_family,"paid candidate projected through original owner")
func c03_original_state(f: Dictionary) -> Dictionary:
 match c03_family:
  "q1":
   for original: Dictionary in f.sim.ink_waves:
    if original.get("source")=="q1":return original
  "q2":
   if not f.sim.ink_rivers.is_empty():return f.sim.ink_rivers.back()
  "q3":return f.sim.ink_mountain
  "e1":return f.sim.ink_rain
  "e2":return f.sim.ink_boat
  "e3":return f.sim.ink_frames
 return {}
func on_event(event: Dictionary,f: Dictionary) -> void:
 super.on_event(event,f)
 if not f.get("c03_watch",false) or f.get("c03_synthetic",false):return
 var original: Dictionary=c03_original_state(f)
 if original.is_empty():return
 var wanted: String={"q1":"ink_q1_released","q2":"ink_q2_river_created","q3":"ink_q3_raised","e1":"ink_e1_entered","e2":"ink_e2_launched","e3":"ink_e3_exchanged"}[c03_family]
 if event.get("kind")!=wanted:return
 var model=f.session.ledger.model
 var buff: Dictionary=f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{}).duplicate(true)
 f["c03_original_committed_state"]=original
 f.c03_notifications.append({"event":event.duplicate(true),"buff":buff,"stats":f.sim.hero.stats.duplicate(true),"original_cast_id":original.cast_id})
 var prior: Dictionary=model.snapshot()
 f.c03_synthetic=true
 f.sim.emit_event(str(event.kind),event.duplicate(true))
 # Even possession of the actual state during a public callback is not the
 # original success seam. Notification depth must prevent borrowing its frame.
 f.sim._equipment_release_committed(c03_family,original)
 f.c03_synthetic=false
 check(model.snapshot()==prior and f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{})==buff,"nested fake emission/private hook cannot borrow outer release")
func c03_release_case() -> void:
 var f: Dictionary=funded_shop("C03 actual "+c03_family)
 if f.is_empty():return
 if not buy(f,C03) or not check(f.session.close_panel().accepted,"original shop closes") or not enter(f,1) or not spawn_ready(f):dispose(f);return
 if not b04_ready(f):dispose(f);return
 var model=f.session.ledger.model
 var before: Dictionary=f.sim.hero.stats.duplicate(true)
 var base: Dictionary=f.sim.hero.base_stats.duplicate(true)
 var projected: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 f["c03_watch"]=true;f["c03_synthetic"]=false;f["c03_notifications"]=[]
 var point: Vector3=f.sim.hero.position+Vector3(.5,0,0)
 var result: Dictionary={}
 match c03_family:
  "q1":
   if not check(f.sim.request_ink_input("q_down").accepted,"actual Q1 initial preview") or not check(f.sim.request_ink_input("escape").accepted,"actual Q1 preview cancelled"):dispose(f);return
   f.sim.request_ink_input("q_up")
   check(model.c03_buff_effect(f.sim).stacks==0 and model.state.get("c03_release_claims",{}).is_empty(),"cancelled Q1 preview has no buff or release claim")
   if not check(f.sim.request_ink_input("q_down").accepted,"actual Q1 armed") or not check(f.sim.request_ink_input("left_down",point).accepted,"actual Q1 drawing begins"):dispose(f);return
   check(model.c03_buff_effect(f.sim).stacks==0,"Q1 charge start does not grant")
   if not check(f.sim.request_ink_input("motion",point+Vector3(.26,0,0)).accepted,"actual Q1 path motion"):dispose(f);return
   result=f.sim.request_ink_input("left_up",point+Vector3(.26,0,0))
  "q2":
   if not check(f.sim.request_action("q2_first",point,"c03-q2-first").accepted,"actual Q2 first point"):dispose(f);return
   var marker_id: int=int(f.sim.ink_q2_pending.cast_id)
   check(model.c03_buff_effect(f.sim).stacks==0 and model.state.get("c03_release_claims",{}).is_empty(),"Q2 first marker no grant or claim")
   check(not f.sim.request_action("q2_second",point,"c03-q2-zero-leg").accepted,"zero-length second leg rejected by original source")
   check(model.c03_buff_effect(f.sim).stacks==0 and int(f.sim.ink_q2_pending.cast_id)==marker_id,"failed second leg keeps original marker without stack")
   result=f.sim.request_action("q2_second",point+Vector3(1,0,0),"c03-q2-second")
   var first_buff: Dictionary=f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{}).duplicate(true)
   var repeated: Dictionary=f.sim.request_action("q2_second",point+Vector3(1,0,0),"c03-q2-second")
   check(repeated.get("accepted",false) and f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{})==first_buff,"same successful source request replay does not grant or refresh")
  "q3":result=f.sim.request_action("q",point)
  "e1","e2":result=f.sim.request_action("e",point)
  "e3":
   if not check(f.sim.request_e3("first",point).accepted,"actual E3 A marker"):dispose(f);return
   check(model.c03_buff_effect(f.sim).stacks==0,"E3 first marker no grant")
   result=f.sim.request_e3("second",point+Vector3(1,0,0))
 if not check(result.get("accepted",false),"actual source accepts release: "+str(result)):dispose(f);return
 var original: Dictionary=f.get("c03_original_committed_state",{})
 if not check(not original.is_empty(),"actual committed original state captured at success notification"):dispose(f);return
 if c03_family=="q1":
  near_number(original.damage,ORIGINAL_INK_TUNING.parameter("Q1-1",int(f.sim.hero.ranks.q))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("Q1-2",int(f.sim.hero.ranks.q)),"original Q1 damage snapshot excludes just-granted stack")
 var effect: Dictionary=model.c03_buff_effect(f.sim)
 check(effect.active and effect.stacks==1,"exactly one release stack")
 near_number(f.sim.hero.stats.ap,float(before.ap)+10.0,"new AP10 projected after original release snapshot")
 near_number(f.sim.hero.stats.move_speed,float(before.move_speed)+float(projected.move_speed)*.02,"original projected-base MS plus2percent")
 check(f.sim.hero.base_stats==base,"base dictionary not baked")
 check(f.c03_notifications.size()==1,"one original successful release notification witnessed")
 var claims: Dictionary=model.state.get("c03_release_claims",{}).duplicate(true)
 check(claims.get("casts",{}).size()==1 and claims.casts.get(str(original.cast_id))==c03_family,"one actual cast claim and exact family")
 if c03_family=="q2":near_number(original.damage,ORIGINAL_INK_TUNING.parameter("Q2-6",int(f.sim.hero.ranks.q))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("Q2-7",int(f.sim.hero.ranks.q)),"original Q2 damage snapshot excludes new stack")
 var e1_saved: Dictionary={}
 if c03_family=="e1":
  e1_saved={"base":float(original.base_damage),"bonus":float(original.bonus_damage),"expected_base":ORIGINAL_INK_TUNING.parameter("E1-6",int(f.sim.hero.ranks.e))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("E1-7",int(f.sim.hero.ranks.e)),"expected_bonus":ORIGINAL_INK_TUNING.parameter("E1-8",int(f.sim.hero.ranks.e))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("E1-9",int(f.sim.hero.ranks.e)),"rain_speed_bonus":f.sim.hero.rain_speed_bonus,"actual_speed":f.sim.hero.speed()}
  near_number(e1_saved.base,e1_saved.expected_base,"E1 original base damage before stack")
  near_number(e1_saved.bonus,e1_saved.expected_bonus,"E1 original bonus damage before stack")
  near_number(f.sim.hero.rain_speed_bonus,ORIGINAL_INK_TUNING.fraction("E1-3",int(f.sim.hero.ranks.e)),"rain temporary speed bonus still original")
 var q3_saved: Dictionary={}
 if c03_family=="q3":
  q3_saved={"raise":float(original.raise_damage),"collapse":float(original.collapse_damage),"expected_raise":ORIGINAL_INK_TUNING.parameter("Q3-2",int(f.sim.hero.ranks.q))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("Q3-3",int(f.sim.hero.ranks.q)),"expected_collapse":ORIGINAL_INK_TUNING.parameter("Q3-9",int(f.sim.hero.ranks.q))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("Q3-10",int(f.sim.hero.ranks.q))}
  near_number(q3_saved.raise,q3_saved.expected_raise,"Q3 original raise snapshot before grant")
  near_number(q3_saved.collapse,q3_saved.expected_collapse,"Q3 original collapse snapshot before grant")
 var original_damage: float=float(original.get("damage",0.0))
 var expected_q1_damage: float=ORIGINAL_INK_TUNING.parameter("Q1-1",int(f.sim.hero.ranks.q))+float(before.ap)*ORIGINAL_INK_TUNING.fraction("Q1-2",int(f.sim.hero.ranks.q)) if c03_family=="q1" else 0.0
 var committed: Dictionary=f.sim.hero.cast_state[OverloadFormula.BUFF_KEY].duplicate(true)
 for _i in range(4):f.sim.common.refresh_stats()
 check(f.sim.hero.cast_state[OverloadFormula.BUFF_KEY]==committed,"repeat stat projection does not refresh duration")
 if c03_family in ["q1","q2"]:near_number(original.damage,original_damage,"repeat refresh preserves original Q1 damage snapshot")
 var second_stage: Dictionary={}
 if c03_family=="e1":
  near_number(original.base_damage,e1_saved.base,"E1 repeat projection retains base damage")
  near_number(original.bonus_damage,e1_saved.bonus,"E1 repeat projection retains bonus damage")
  second_stage=f.sim.request_action("ink_e_up",point,"c03-e1-release")
  if not check(second_stage.get("accepted",false),"original E1 physical release reforms"):dispose(f);return
  check(f.sim.ink_rain.is_empty() and is_zero_approx(f.sim.hero.rain_speed_bonus),"original rain form and speed bonus removed")
  check(f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{})==committed and model.state.get("c03_release_claims",{})==claims,"E1 reform does not grant or refresh a second stack")
 if c03_family=="q3":
  near_number(original.raise_damage,q3_saved.raise,"Q3 refresh retains raise snapshot")
  near_number(original.collapse_damage,q3_saved.collapse,"Q3 refresh retains collapse snapshot")
  if not b04_ready(f):dispose(f);return
  second_stage=f.sim.request_action("q",point+Vector3(1,0,0),"c03-q3-collapse")
  if not check(second_stage.get("accepted",false),"original Q3 second-stage collapse accepted"):dispose(f);return
  check(f.sim.ink_mountain.is_empty(),"original terrain removed by collapse")
  check(f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{})==committed and model.state.get("c03_release_claims",{})==claims,"same-cast Q3 collapse neither grants nor refreshes")
 c03_release_samples.append({"family":c03_family,"e1_snapshots":e1_saved,"q3_snapshots":q3_saved,"second_stage":second_stage,"original_damage":original_damage,"expected_q1_damage":expected_q1_damage,"damage_after_refresh":original.get("damage",0.0),"result":result.duplicate(true),"before":before,"after":f.sim.hero.stats.duplicate(true),"base":base,"projected":projected,"effect":effect,"buff":committed,"claims":claims.duplicate(true),"notifications":f.c03_notifications.duplicate(true),"selected_hex":model.state.selected_hex.duplicate(true)})
 dispose(f)
func run() -> void:
 g03_reset_evidence();c03_release_case();await process_frame
 check(c03_release_samples.size()==1,"one completed actual source release sample required")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"family":c03_family,"samples":c03_release_samples,"wallet_fixture":60000,"HP_written":false,"native_GUI":false,"original_Sim_input_API":true,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
