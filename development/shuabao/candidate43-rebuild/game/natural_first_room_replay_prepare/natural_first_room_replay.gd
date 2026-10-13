extends SceneTree
## External source-input replay plus read-only original first-room observer.
## Synthetic player inputs, never native GUI/CUA completion evidence.
## Original Host alone owns held-basic updates and simulation time.
const ENTRY := "res://visual_rework_20261009/entry.tscn"
const SOURCE_BINDING := "res://visual_rework_20261009/binding/source_binding.json"
const SOURCE_SHA := "da26defba5cbdcf2ca2b0a7e51d03ed0345f2525336d3543598df5090c001360"
const WALL_MS := 100000
var entry: Node
var host: Node
var sim: Node
var session: RefCounted
var model: RefCounted
var output: String=""
var loaded_source_sha: String=""
var started_ms: int=0
var initial: Dictionary={}
var identities: Dictionary={}
var roster: Array=[]
var roster_ids: Array=[]
var first_room: String=""
var first_generation: int=-1
var events: Array=[]
var terminals: Array=[]
var check_records: Array=[]
var failures: Array=[]
var io_errors: Array=[]
var checkpoints: Array=[]
var last_observed: Dictionary={}
var finishing: bool=false
var driver: RefCounted

func _initialize() -> void:
 started_ms=Time.get_ticks_msec()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--natural-evidence="):output=arg.trim_prefix("--natural-evidence=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 check_records.append({"passed":ok,"label":label})
 if not ok:failures.append(label)
 return ok

func json_value(value: Variant) -> Variant:
 if value is Dictionary:
  var out: Dictionary={}
  for key: Variant in value:out[str(key)]=json_value(value[key])
  return out
 if value is Array:
  var out: Array=[]
  for item: Variant in value:out.append(json_value(item))
  return out
 if value is Vector2:return {"x":value.x,"y":value.y}
 if value is Vector3:return {"x":value.x,"y":value.y,"z":value.z}
 if value is Color:return {"r":value.r,"g":value.g,"b":value.b,"a":value.a}
 if value is Object:return {"object_class":value.get_class(),"instance_id":value.get_instance_id()}
 return value

func save_json(name: String, data: Dictionary) -> void:
 var file: FileAccess=FileAccess.open(output.path_join(name),FileAccess.WRITE)
 if file==null:io_errors.append("cannot_open:"+name);return
 file.store_string(JSON.stringify(json_value(data),"  "))
 var error: Error=file.get_error();file.close()
 if error!=OK:io_errors.append("cannot_write:"+name+":"+str(error))

func identity() -> Dictionary:
 return {"entry":entry.get_instance_id(),"host":host.get_instance_id(),"sim":sim.get_instance_id(),"session":session.get_instance_id(),"ledger":session.ledger.get_instance_id(),"model":model.get_instance_id(),"hero":sim.hero.get_instance_id(),"common":sim.common.get_instance_id(),"clock":sim.clock.get_instance_id(),"director":sim.enemy_director.get_instance_id(),"run_id":session.run_id}

func selected_hex_definitions() -> Dictionary:
 var out: Dictionary={}
 for id: String in model.state.selected_hex:out[id]=model.config.hexes.get(id,{}).duplicate(true)
 return out

func observe() -> Dictionary:
 var rewards: Dictionary={}
 for id: Variant in model.state.reward_ids:
  var key: String="ink-reward:"+str(id)
  if model.receipts.has(key):rewards[str(id)]=model.receipts[key].duplicate(true)
 var actors: Array=[]
 for enemy: Dictionary in sim.enemies:
  actors.append({"actor_id":enemy.actor_id,"kind":enemy.kind,"hp":enemy.hp,"max_hp":enemy.get("max_hp",null),"dead":enemy.dead,"state":enemy.state,"generation":enemy.get("generation",-1),"room_id":enemy.get("room_id",""),"position":enemy.position})
 return {"wall_elapsed_ms":Time.get_ticks_msec()-started_ms,"identities":identity(),"source_binding_sha256":loaded_source_sha,"phase":sim.phase,"paused":sim.paused,"hero_dead":sim.hero.dead,"hero_hp":sim.hero.hp,"hero_stats":sim.hero.stats.duplicate(true),"hero_position":sim.hero.position,"hero_time":sim.hero_time,"ai_enabled":sim.ai_enabled,"auto_finish":sim.auto_finish,"generation":sim.encounter_generation,"room_id":sim.room_id,
  "model_state":model.snapshot(),"flow":session.snapshot(),"original_reward_receipts":rewards,"reward_binding":model.reward_binding(),"selected_hex_definitions":selected_hex_definitions(),"actors":actors,"source_events_seen":events.size(),"source_kills_seen":kill_count(),"host_inputs":host.inputs.duplicate(true),"host_initial_actions":host.initial_actions.duplicate(true),"host_startup_error":host.startup_session_error,"host_floor_error":host.floor_error}

func kill_count() -> int:
 var count: int=0
 for event: Dictionary in events:
  if event.get("kind")=="kill":count+=1
 return count

func on_source_event(event: Dictionary) -> void:
 # Observation only: never call Session.observe_event or damage/step/input APIs.
 if events.size()<20000:events.append(event.duplicate(true))
 elif not "source_event_capacity_exceeded" in failures:failures.append("source_event_capacity_exceeded")

func on_source_terminal(snapshot: Dictionary) -> void:
 terminals.append(snapshot.duplicate(true))

func capture(label: String, state: Dictionary) -> void:
 var prefix: String="%02d_%s"%[checkpoints.size(),label]
 save_json(prefix+".json",state)
 # A screenshot is read only after the real renderer finishes its frame.
 await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 var error: Error=image.save_png(output.path_join(prefix+".png"))
 if error!=OK:io_errors.append("screenshot_failed:"+prefix+":"+str(error))
 checkpoints.append({"label":label,"json":prefix+".json","png":prefix+".png","observed_ms":state.get("wall_elapsed_ms",-1),"after_draw_ms":Time.get_ticks_msec()-started_ms,"screenshot_error":error})
 save_json("checkpoint_index.json",{"checkpoints":checkpoints})

func latch_original_roster(state: Dictionary) -> void:
 if not roster_ids.is_empty() or state.phase!="combat":return
 var selected: Dictionary=state.flow.row_state.selected_node
 if not check(selected.get("node_id","")=="r01a" and int(selected.get("row_number",-1))==1,"source replay enters exactly authored first row r01a"):return
 first_room=str(state.room_id);first_generation=int(state.generation)
 roster_ids=session.expected_enemies.duplicate(true)
 roster=state.actors.duplicate(true)
 check(roster_ids.size()==4 and roster.size()==4,"r01a contains its four original admitted enemies")
 for enemy: Dictionary in roster:
  check(enemy.actor_id in roster_ids and enemy.kind=="minion" and int(enemy.generation)==first_generation and enemy.room_id==first_room,"original r01a minion identity/scope "+str(enemy.actor_id))
 save_json("first_room_roster.json",{"room_id":first_room,"generation":first_generation,"expected_ids":roster_ids,"actors_at_first_observation":roster,"selected_node":selected})

func verify_first_room_success(state: Dictionary) -> bool:
 # Original Session already authenticates source death, roster, reward and
 # completion before between_rooms. Inspect those receipts; do not re-adjudicate.
 check(state.phase=="victory" and state.flow.status=="between_rooms" and not state.hero_dead,"living original source victory settles to between_rooms")
 var completed: Array=state.flow.row_state.get("completed_rows",[])
 check(completed.size()==1 and int(state.flow.node_index)==1,"exactly one original row completion, not a full-floor victory")
 if completed.size()==1:check(completed[0].identity.node_id=="r01a" and int(completed[0].identity.row_number)==1,"original completion receipt identifies r01a")
 if completed.size()==1:
  var entered: Dictionary=completed[0].entry.payload
  check(str(entered.get("room_id",""))==first_room and int(entered.get("generation",-1))==first_generation,"completed row entry matches first observed room and generation")
 check(terminals.size()==1,"exactly one source terminal snapshot for the first room")
 if terminals.size()==1:
  check(str(terminals[0].get("room_id",""))==first_room and int(terminals[0].get("generation",-1))==first_generation and terminals[0].get("phase","")=="victory","source terminal matches observed first-room victory scope")
 check(state.flow.fault.is_empty() and state.host_startup_error.is_empty() and state.host_floor_error.is_empty(),"original flow and Host remain fault-free")
 check(state.identities==identities and roster_ids.size()==4 and state.actors.size()==4 and session.kill_receipts.size()==4,"same owners and four original actors have four authentic Session kill receipts")
 var observations: Dictionary={}
 for id: String in roster_ids:
  var damages: Array=[]
  var kills: Array=[]
  for event: Dictionary in events:
   if str(event.get("target",""))!=id:continue
   if event.get("kind")=="damage" and float(event.get("amount",0.0))>0.0:damages.append(event)
   if event.get("kind")=="kill":kills.append(event)
  var target: Dictionary=sim.enemy_by_id(id)
  var kill: Dictionary=session.kill_receipts.get(id,{})
  check(int(kill.get("generation",-1))==first_generation,"Session kill receipt belongs to first observed generation: "+id)
  if kills.size()==1:check(kill.get("event",{})==kills[0],"Session authenticated kill equals the actual observed source event: "+id)
  var reward_id: String=str(kill.get("reward_id",""))
  var reward: Dictionary=model.receipts.get("ink-reward:"+reward_id,{})
  check(not damages.is_empty() and kills.size()==1 and not target.is_empty() and target.dead,"observed real damage and one source death for original "+id)
  check(not kill.is_empty() and reward_id in model.state.reward_ids and reward.get("request",{}).get("action","")=="reward_minion" and reward.get("result",{}).get("accepted",false),"original Session and Model accepted the kill/reward for "+id)
  observations[id]={"damage":damages,"kill":kills,"session_receipt":kill,"model_reward_receipt":reward}
 save_json("natural_reward_evidence.json",{"original_receipts":observations,"selected_hexes":selected_hex_definitions(),"initial_gold":initial.model_state.gold,"actual_final_gold":state.model_state.gold,"actual_final_xp":state.model_state.xp,"actual_final_level":state.model_state.level,"fixed_gold_or_xp_total_assumed":false})
 return failures.is_empty() and io_errors.is_empty()

func finish(reason: String, state: Dictionary) -> void:
 finishing=true
 # Freeze the genuine terminal/pre-exit state BEFORE releasing the entry.
 # Never press F10 or call close_run to manufacture a terminal state.
 save_json("pre_exit_state.json",state)
 var successful: bool=false
 if reason=="first_room_settled":successful=verify_first_room_success(state)
 else:check(false,"natural first room incomplete: "+reason)
 await capture("final_"+reason,state)
 var report: Dictionary={"passed":successful and failures.is_empty() and io_errors.is_empty(),"reason":reason,"checks":check_records,"failures":failures,"io_errors":io_errors,"initial":initial,"pre_exit":state,"original_roster":roster,"expected_roster_ids":roster_ids,"events":events,"terminals":terminals,"checkpoints":checkpoints,"automatic_gameplay_actions":driver.receipts.duplicate(true) if driver!=null else [],"replay_visibility":driver.visibility_log.duplicate(true) if driver!=null else [],"input_replay":true,"native_input":false,"startup_actions":["load actual entry","request_start yanguizhou"],"wallet_HP_AI_enemy_clock_fixtures":false,"extra_sim_steps":false,"source_input_injection":true,"native_input_provenance":"Synthetic events through the original HUD/Controller and input router; not OS input, native CUA, or a manual-clear claim.","natural_first_room_only":true,"full_floor_victory":false,"selected_hex_may_affect_economy_or_xp":true,"hardcoded_gold_xp_total":false,"wall_limit_ms":WALL_MS,"wall_elapsed_ms":Time.get_ticks_msec()-started_ms,"source_binding_sha256":loaded_source_sha}
 save_json("report.json",report)
 print("NATURAL_FIRST_ROOM_REPLAY ",JSON.stringify({"passed":report.passed,"reason":reason,"gold":state.get("model_state",{}).get("gold",-1),"xp":state.get("model_state",{}).get("xp",-1),"result":output.path_join("report.json")}))
 if is_instance_valid(entry):entry.free()
 await process_frame
 quit(0 if report.passed and io_errors.is_empty() else 2)

func run() -> void:
 if output.is_empty() or not output.is_absolute_path():push_error("absolute --natural-evidence directory required");quit(2);return
 if DirAccess.make_dir_recursive_absolute(output)!=OK:push_error("cannot create natural evidence directory");quit(2);return
 if DisplayServer.get_name()=="headless":save_json("report.json",{"passed":false,"reason":"original_GUI_renderer_required_for_camera_visibility"});quit(2);return
 loaded_source_sha=FileAccess.get_sha256(SOURCE_BINDING)
 if not check(loaded_source_sha==SOURCE_SHA,"exact sealed training12 production source is loaded"):
  save_json("report.json",{"passed":false,"failures":failures});quit(2);return
 var scene: PackedScene=load(ENTRY)
 if scene==null:save_json("report.json",{"passed":false,"reason":"actual_entry_missing"});quit(2);return
 entry=scene.instantiate();root.add_child(entry)
 await process_frame
 entry.request_start("yanguizhou")
 while Time.get_ticks_msec()-started_ms<WALL_MS:
  await process_frame
  if is_instance_valid(entry.active_room) and is_instance_valid(entry.visual_controller):
   host=entry.active_room
   if host.shop_session!=null and host.shop_session.ledger!=null and host.shop_session.ledger.model!=null:
    session=host.shop_session;model=session.ledger.model;sim=host.sim;break
 if not is_instance_valid(sim):
  save_json("report.json",{"passed":false,"reason":"startup_not_ready_within100seconds","wall_elapsed_ms":Time.get_ticks_msec()-started_ms})
  if is_instance_valid(entry):entry.free()
  await process_frame;quit(2);return
 identities=identity()
 sim.combat_event.connect(on_source_event)
 sim.encounter_finished.connect(on_source_terminal)
 initial=observe()
 check(int(initial.model_state.gold)==0 and int(initial.model_state.xp)==0 and int(initial.model_state.level)==1 and int(initial.model_state.points)==1,"genuine fresh zero gold zero XP level1 one SP")
 check(initial.model_state.inventory.is_empty() and initial.model_state.body.is_empty() and initial.model_state.selected_hex.is_empty() and initial.model_state.pending_milestones==[1],"no equipment, training or automated initial Hex choice")
 check(initial.ai_enabled and not initial.auto_finish,"original preparation retains AI flag and intentionally disables combat auto-finish")
 check(initial.phase=="preparation" and initial.flow.status=="preparation" and int(initial.generation)==0 and initial.actors.is_empty(),"original preparation before any selected or entered battle")
 for skill: Dictionary in initial.model_state.skills.values():check(int(skill.rank)==0,"fresh skills remain unlearned before source input replay")
 await capture("initial_zero_start",initial)
 if not failures.is_empty():await finish("startup_contract_failed",initial);return
 var driver_script: Script=load(get_script().resource_path.get_base_dir().path_join("visible_player_replay.gd"))
 if driver_script==null:await finish("replay_driver_missing",initial);return
 driver=driver_script.new()
 driver.bind_existing(host,started_ms+WALL_MS)
 save_json("ready.json",{"ready":true,"input_replay":true,"native_input":false,"automatic_actions":["visible offered initial Hex slot1","original1SP Q1 learning","original r01a selection/entry","visible-target WASD, held BASIC and Q1 gesture"],"deadline_wall_ms_from_script_start":WALL_MS,"identities":identities,"initial_snapshot":"00_initial_zero_start.json"})
 var prepared: Dictionary=await driver.prepare_first_room()
 save_json("replay_preparation.json",prepared)
 if not check(prepared.get("accepted",false),"legal original Hex/Q1/r01a replay preparation"):
  await finish("replay_preparation_failed",observe());return
 var last_key: String=""
 var last_save: int=0
 while Time.get_ticks_msec()-started_ms<WALL_MS:
  await process_frame
  if not is_instance_valid(entry) or not is_instance_valid(host) or not is_instance_valid(sim):
   await finish("original_owner_released",last_observed if not last_observed.is_empty() else initial);return
  var state: Dictionary=observe();last_observed=state.duplicate(true)
  if state.identities!=identities:check(false,"original source identity changed");await finish("identity_changed",state);return
  if not state.ai_enabled or (state.phase=="combat" and not state.auto_finish):check(false,"original AI or terminal authority disabled");await finish("source_authority_changed",state);return
  latch_original_roster(state)
  var selected: Dictionary=state.flow.row_state.get("selected_node",{})
  if not selected.is_empty() and (selected.get("node_id","")!="r01a" or int(selected.get("row_number",-1))!=1):await finish("wrong_replay_route_selection",state);return
  if not state.flow.fault.is_empty() or not state.host_floor_error.is_empty():await finish("original_flow_fault",state);return
  if state.hero_dead or state.flow.status=="defeated":await finish("natural_death",state);return
  if state.flow.status in ["aborted","faulted"]:await finish("original_run_"+str(state.flow.status),state);return
  if state.phase=="victory" and state.flow.status=="between_rooms":await finish("first_room_settled",state);return
  var key: String=str(state.phase)+"|"+str(state.flow.status)+"|"+str(state.source_kills_seen)+"|"+str(state.model_state.selected_hex)+"|"+str(state.model_state.skills.Q.rank)+"|"+str(selected.get("node_id",""))
  if key!=last_key:
   last_key=key
   await capture("phase_"+str(state.phase)+"_kills_"+str(state.source_kills_seen),state)
  driver.advance_inputs()
  if not driver.failure.is_empty():check(false,driver.failure);await finish("replay_input_contract_failed",observe());return
  if Time.get_ticks_msec()-last_save>=500:
   last_save=Time.get_ticks_msec();save_json("last_observed.json",state)
   save_json("replay_input_receipts.json",{"actions":driver.receipts,"visibility":driver.visibility_log})
 await finish("wall_limit100seconds",observe())
