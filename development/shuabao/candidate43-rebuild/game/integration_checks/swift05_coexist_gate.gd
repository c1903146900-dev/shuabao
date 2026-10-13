extends "res://integration_checks/swift05_source_gate.gd"
const CoexistSwift=preload("res://elixir_swift_20261010/runtime.gd")
var coexist_mode: String="plain"
var coexist_samples: Array=[]
var coexist_attempts: Array=[]
var coexist_fixture: Dictionary={}
func _initialize()->void:
 output_path="user://swift_c03.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--swift-group="):coexist_mode=arg.trim_prefix("--swift-group=")
 if coexist_mode not in ["plain","extra_move"]:quit(2);return
 run.call_deferred()
func coexist_case()->void:
 var f: Dictionary=funded_shop("Swift C03 actual "+coexist_mode)
 if f.is_empty():return
 coexist_fixture=f
 var m=f.session.ledger.model
 if not check(f.session.close_panel().accepted,"original preparation shop closes"):dispose(f);return
 for row: int in [1,2]:
  if not g06_enter_original(f,row,"r%02da"%row) or not settle_fixture_combat(f):dispose(f);return
 if not choose_required_hexes(f):dispose(f);return
 var points: int=int(m.state.points)
 if not check(points>=1,"original prior combat rewards supply E1 SP") or not check(command(f,"learn",{"slot":"E","candidate":"E1","expected_rank":0}).get("accepted",false),"learn E1 from actual earned SP"):dispose(f);return
 check(int(m.state.points)==points-1 and f.sim.hero.ranks.e==1 and f.sim.hero.ranks.q==1 and f.sim.hero.ranks.passive==0,"original E1 payment and Q1 retained without P2")
 if not g06_enter_original(f,3,"r03a") or not check(f.session.complete_service().get("accepted",false),"original rest completes") or not g06_enter_original(f,4,"r04a") or not check(f.session.complete_service().get("accepted",false),"original training service completes"):dispose(f);return
 if not g02_open(f) or not buy(f,C03):dispose(f);return
 var gear_fraction: float=.07 if coexist_mode=="extra_move" else 0.0
 if coexist_mode=="extra_move":
  var gear_gold: int=int(m.state.gold)
  if not buy(f,"base:B08"):dispose(f);return
  check(int(m.state.gold)==gear_gold-500,"original B08 price500 actually paid")
  near_number(m.equipment_runtime_status("base:B08").stats.get("move_speed",-1.0),.07,"fixed formal B08 seven percent definition")
 var base: Dictionary=f.sim.hero.base_stats.duplicate(true)
 var before_drink: Dictionary=f.sim.hero.stats.duplicate(true)
 near_number(m.equipment_effects().stats.get("move_speed",0.0),gear_fraction,"original B08 contributes exactly7percent only in extra mode")
 near_number(before_drink.move_speed,float(base.move_speed)*(1.0+gear_fraction),"safe original other-equipment MS basis")
 if not buy(f,SWIFT) or not check(shop_command(f,"consume",{"uid":swift_uid(f)}).get("accepted",false),"drink original Swift UID after preparation") or not check(f.session.close_panel().accepted,"close target preparation shop") or not g06_enter_original(f,5,"r05a") or not spawn_ready(f):dispose(f);return
 for id: String in f.sim.common.runtime.selected:
  if id.begins_with("g"):check(false,"uncovered actual common modifier "+id);dispose(f);return
 if not check(m.swift_elixir_status().active and m.c03_buff_effect(f.sim).stacks==0,"current target battle binds Swift with zero C03 stacks"):dispose(f);return
 var target: Dictionary=g02_nearest(f)
 if not check(not target.is_empty(),"actual target roster exists") or not b04_approach(f,target,1.0) or not b04_ready(f):dispose(f);return
 var away: Vector3=f.sim.hero.position-target.position
 if not check(away.length_squared()>.000001,"finite nonzero original away aim"):dispose(f);return
 var aim: Vector3=f.sim.hero.position+away.normalized()*8.0
 var key:=InputEventKey.new();key.physical_keycode=KEY_SHIFT;key.pressed=true
 var dash: Dictionary=f.router.handle_event(key,aim)
 key=InputEventKey.new();key.physical_keycode=KEY_SHIFT;key.pressed=false;f.router.handle_event(key,aim)
 coexist_attempts.append({"stage":"shift","result":dash.duplicate(true),"aim":aim,"hero":f.sim.hero.snapshot().duplicate(true)})
 if not check(dash.get("accepted",false),"original Shift accepted: "+str(dash)):dispose(f);return
 for _tick in range(120):
  if f.sim.hero.dash_left<=0.0:break
  step(f)
 if not check(f.sim.phase=="combat" and not f.sim.hero.dead and m.swift_buff_effect(f.sim).active,"real natural Shift grants short effect in target battle"):dispose(f);return
 var swift: Dictionary=f.sim.hero.cast_state[CoexistSwift.BUFF_KEY].duplicate(true)
 var projected: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 var pre_q: Dictionary=f.sim.hero.stats.duplicate(true)
 near_number(pre_q.move_speed,float(base.move_speed)*(1.0+gear_fraction+.30),"actual permanent plus short and original gear basis")
 var event_start: int=f.events.size()
 var q: Dictionary=g02_q1(f,target)
 coexist_attempts.append({"stage":"q1","result":q.duplicate(true),"actor_time":f.sim.common.runtime.actor_time})
 if not check(q.get("accepted",false),"actual Q1 release accepted"):dispose(f);return
 var qstate: Dictionary={}
 for wave: Dictionary in f.sim.ink_waves:
  if wave.get("source")=="q1":qstate=wave
 if not check(not qstate.is_empty() and m.c03_buff_effect(f.sim).stacks==1,"original Q1 state and one actual C03 release stack"):dispose(f);return
 check(q.has("cast_id") and int(qstate.cast_id)==int(q.cast_id),"original Q1 retained state matches accepted cast receipt")
 var first: Dictionary=f.sim.hero.cast_state[OverloadFormula.BUFF_KEY].duplicate(true)
 var q_expected: float=ORIGINAL_INK_TUNING.parameter("Q1-1",1)+float(pre_q.ap)*ORIGINAL_INK_TUNING.fraction("Q1-2",1)
 near_number(qstate.damage,q_expected,"Q1 original snapshot excludes its new stack")
 var c03_basis: float=float(base.move_speed)*(1.0+gear_fraction)
 var expected_one: float=float(base.move_speed)*(1.0+gear_fraction+.30)+c03_basis*.02
 var expected_two: float=float(base.move_speed)*(1.0+gear_fraction+.30)+c03_basis*.04
 near_number(f.sim.hero.stats.move_speed,expected_one,"one C03 layer preserves other gear term and excludes Swift cross term")
 step(f)
 if not check(f.sim.phase=="combat" and not f.sim.hero.dead and m.swift_buff_effect(f.sim).active,"real next actor tick remains alive inside Swift duration"):dispose(f);return
 var before_e_ap: float=float(f.sim.hero.stats.ap)
 key=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=true
 var edown: Dictionary=f.router.handle_event(key,target.position)
 coexist_attempts.append({"stage":"e1_down","result":edown.duplicate(true),"actor_time":f.sim.common.runtime.actor_time})
 if not check(edown.get("accepted",false) and not f.sim.ink_rain.is_empty(),"actual E1 release enters original rain form: "+str(edown)):dispose(f);return
 var original_rain: Dictionary=f.sim.ink_rain
 var rain: Dictionary=original_rain.duplicate(true)
 var second: Dictionary=f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{}).duplicate(true)
 if not check(m.swift_buff_effect(f.sim).active and f.sim.hero.cast_state[CoexistSwift.BUFF_KEY]==swift and m.c03_buff_effect(f.sim).stacks==2 and float(second.expires_at)>float(first.expires_at),"second actual different release grants second stack and refreshes later deadline"):dispose(f);return
 near_number(second.expires_at,float(f.sim.common.runtime.actor_time)+4.0,"second C03 grant refreshes original4seconds")
 near_number(rain.base_damage,ORIGINAL_INK_TUNING.parameter("E1-6",1)+before_e_ap*ORIGINAL_INK_TUNING.fraction("E1-7",1),"E1 impact snapshot precedes second new AP10")
 near_number(rain.bonus_damage,ORIGINAL_INK_TUNING.parameter("E1-8",1)+before_e_ap*ORIGINAL_INK_TUNING.fraction("E1-9",1),"E1 bonus snapshot precedes second new AP10")
 near_number(f.sim.hero.stats.move_speed,expected_two,"two-layer stat projection uses approved narrow additive formula")
 var slow_factor: float=1.0-clampf(float(f.sim.hero.slow_amount),0.0,1.0) if f.sim.hero.slow_left>0.0 else 1.0
 var rain_bonus: float=ORIGINAL_INK_TUNING.fraction("E1-3",1)
 near_number(f.sim.hero.rain_speed_bonus,rain_bonus,"original rain independent bonus retained")
 near_number(f.sim.hero.speed(),maxf(0.0,expected_two*slow_factor)*(1.0+rain_bonus),"actual rain movement speed retains original independent multiplier")
 var rain_speed: float=f.sim.hero.speed()
 key=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=false
 var eup: Dictionary=f.router.handle_event(key,target.position)
 coexist_attempts.append({"stage":"e1_up","result":eup.duplicate(true)})
 if not check(eup.get("accepted",false),"original E1 keyup accepted"):dispose(f);return
 for _tick in range(3):
  if f.sim.ink_rain.is_empty():break
  step(f)
 if not check(f.sim.ink_rain.is_empty() and f.sim.hero.rain_speed_bonus==0.0 and m.swift_buff_effect(f.sim).active and m.c03_buff_effect(f.sim).stacks==2,"rain reformed while both approved effects remain active"):dispose(f);return
 near_number(f.sim.hero.stats.move_speed,expected_two,"after reform actual two-layer MS has no rain multiplier")
 check(f.sim.hero.cast_state[CoexistSwift.BUFF_KEY]==swift,"Q1 E1 do not refresh Swift deadline")
 var hits: Array=[]
 for event: Dictionary in f.events.slice(event_start):
  if event.get("kind")=="damage" and event.get("source")=="q1" and int(event.get("cast_id",-1))==int(qstate.cast_id) and str(event.get("target","")) in f.session.expected_enemies:
   check(int(event.get("generation",-1))==f.sim.encounter_generation and str(event.get("room_id",""))==f.sim.room_id,"actual Q1 packet current room generation")
   hits.append(event.duplicate(true))
 if not check(not hits.is_empty(),"actual original same-cast Q1 hits current roster"):dispose(f);return
 b04_integrity(f,"actual Swift C03 owner source chain")
 var final: Dictionary=f.sim.hero.stats.duplicate(true)
 for _i in range(4):f.sim.common.refresh_stats()
 near_number(qstate.damage,q_expected,"original Q1 snapshot remains unchanged through E1 and repeated refresh")
 near_number(original_rain.base_damage,rain.base_damage,"original E1 base snapshot unchanged through reform and repeated refresh")
 near_number(original_rain.bonus_damage,rain.bonus_damage,"original E1 bonus snapshot unchanged through reform and repeated refresh")
 check(f.sim.hero.stats==final and f.sim.hero.base_stats==base and f.sim.hero.projected_base_stats==projected,"repeated composition projection preserves all final stats and inputs")
 check(f.sim.hero.cast_state[CoexistSwift.BUFF_KEY]==swift and f.sim.hero.cast_state[OverloadFormula.BUFF_KEY]==second,"projection does not refresh either deadline")
 coexist_samples.append({"mode":coexist_mode,"base":base,"projected":projected,"before_drink":before_drink,"expected_one":expected_one,"expected_two":expected_two,"actual":final,"rain_speed":rain_speed,"rain_bonus":rain_bonus,"slow_factor":slow_factor,"swift":swift,"C03_first":first,"C03_second":second,"Q1_damage":qstate.damage,"Q1_expected":q_expected,"E1_state":rain,"Q1_hits":hits,"events":f.events.slice(event_start).duplicate(true),"selected_hexes":f.sim.common.runtime.selected.duplicate(),"prior_source_lethal_packets":fixture_packets.duplicate(true)})
 dispose(f)
func run()->void:
 g03_reset_evidence();coexist_case();dispose(coexist_fixture);await process_frame
 check(coexist_samples.size()==1,"one fully completed original coexistence sample")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":coexist_mode,"completed":[coexist_mode] if coexist_samples.size()==1 else [],"samples":coexist_samples,"attempts":coexist_attempts,"wallet_fixture":60000,"prior_room_source_lethal_fixture":true,"target_HP_or_clock_write":false,"native_GUI":false,"six_stack_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file:=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
