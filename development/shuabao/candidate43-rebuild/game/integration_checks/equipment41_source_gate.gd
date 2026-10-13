extends "res://integration_checks/equipment41_g02_regression_gate.gd"
## Original Host/Session source gate. All HP and shield changes use original
## damage/heal/shield consumers. Parent alone runs/parses the engine.
const D04_ITEM := "final:D04"
const D04_SHIELD := "equipment_passive20"
const D04_GROUPS := ["threshold_unique_replays","lethal_original_terminal"]
var d04_required: Array = D04_GROUPS.duplicate()
var d04_completed: Array = []
var d04_partition: String = "all"
var d04_packets: Array = []
var d04_shield_records: Array = []
var d04_heals: Array = []

func _initialize() -> void:
 output_path = "user://equipment41_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--d04-source-group="): d04_partition = arg.trim_prefix("--d04-source-group=")
 if d04_partition != "all":
  if d04_partition not in D04_GROUPS: push_error("Unknown D04 source group");quit(2);return
  d04_required = [d04_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 f["d04_shields"] = []
 f["d04_original_metadata"] = {}
 f["d04_original_commit"] = {}
 if not check(f.sim.d04_model_is_bound(f.session.ledger.model) and f.session.ledger.model.equipment_runtime_status(D04_ITEM).get("runtime_complete",false),"D04 exact original owner and HP hook bridge bound"):
  dispose(f);return {}
 return f

func d04_view(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.lifeline_status().duplicate(true)
func d04_raw(f: Dictionary) -> Dictionary:
 return f.sim.hero.shields.get(D04_SHIELD,{}).duplicate(true)
func d04_quota(f: Dictionary) -> Dictionary:
 return f.session.ledger.model._d04_quota().duplicate(true)
func d04_receipts(f: Dictionary) -> Array:
 var found: Array = []
 for id: String in f.session.ledger.model.receipts:
  var receipt: Dictionary = f.session.ledger.model.receipts[id]
  if receipt.request.action == "d04_verified_room_shield" and receipt.result.get("accepted",false): found.append({"id":id,"request":receipt.request.duplicate(true),"result":receipt.result.duplicate(true)})
 return found

func on_event(event: Dictionary, f: Dictionary) -> void:
 if f.has("d04_shields") and event.get("kind") == "shield" and event.get("source") == D04_SHIELD:
  # Read actual private metadata identity while the real post-HP hook is open;
  # it is used later ONLY for negative repeat calls, never to grant a shield.
  var frame: Dictionary = f.sim._d04_hp_notifications.back() if not f.sim._d04_hp_notifications.is_empty() else {}
  var witness: Dictionary = {}
  if not frame.is_empty():
   f.d04_original_metadata = frame.metadata
   witness = f.sim.verify_d04_hp_commit(f.session.ledger.model,frame.metadata,f.session.run_id)
   f.d04_original_commit = witness.get("commit",{}).duplicate(true)
  var record: Dictionary = {"event":event.duplicate(true),"witness":witness,"quota_at_observer":d04_quota(f),"shield_at_observer":d04_raw(f),"hero_hp":f.sim.hero.hp,"final_max_hp":f.sim.hero.stats.max_hp,"actor_time":f.sim.common.runtime.actor_time}
  check(not witness.is_empty(),"original D04 shield notification still has exact source HP-commit witness")
  check(d04_view(f).used_in_room and not d04_raw(f).is_empty(),"room quota and actual shield both committed before original shield observers")
  f.d04_shields.append(record);d04_shield_records.append(record)
 super.on_event(event,f) # Exactly one original Session observer remains.

func d04_start(label: String, copies: int = 1) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return {}
 for _copy: int in range(copies):
  if not buy(f,D04_ITEM):dispose(f);return {}
 if not check(f.session.close_panel().get("accepted",false),"D04 original shop closes") or not enter(f,1):dispose(f);return {}
 # Real original encounter is entered; damage_hero does not require enemy
 # spawn grace. No source step is needed before these synchronous HP cases.
 if not check(f.session.status=="combat" and f.sim.phase=="combat" and not f.sim.paused and not f.sim.hero.dead,"original live room accepts explicit incoming fixture"):
  dispose(f);return {}
 if not evidence.has("d04_entry_conditions"):evidence["d04_entry_conditions"]=[]
 evidence.d04_entry_conditions.append({"group":label,"copies":copies,"hp":f.sim.hero.hp,"max_hp":f.sim.hero.stats.max_hp,"selected_hex":f.session.ledger.model.state.selected_hex.duplicate(true),"original_shields":f.sim.hero.shields.duplicate(true),"d04_quota":d04_quota(f),"equipment_purchase_does_not_heal":true})
 return f

func d04_damage_to(f: Dictionary, remaining: float, label: String) -> Dictionary:
 var before: float = float(f.sim.hero.hp)
 var shield_before: float = float(f.sim.hero.shield_total())
 if not check(remaining>=0.0 and remaining<before,"incoming fixture requests a genuine HP decrease: "+label):return {}
 var amount: float = before-remaining+shield_before
 var metadata: Dictionary = {"source":"equipment41_incoming_fixture","fixture":true,"purpose":label,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id}
 var start: int = f.events.size()
 var before_quota: Dictionary = d04_quota(f)
 var before_shields: Dictionary = d04_raw(f)
 # Explicit deterministic source damage fixture: mandatory+true bypasses
 # enemy scaling/defence/admission immunity, but retains original HP commit,
 # shield absorption, threshold hooks, damage notification and true death.
 f.sim.damage_hero(amount,Vector3.ZERO,0.0,true,true,metadata)
 var record: Dictionary = {"label":label,"source_api":"original damage_hero","actual_skill_or_enemy_AI":false,"mandatory_true_fixture":true,"requested":amount,"before_hp":before,"after_hp":f.sim.hero.hp,"expected_hp":remaining,"final_max_hp":f.sim.hero.stats.max_hp,"total_shield_before":shield_before,"shield_before":before_shields,"shield_after":d04_raw(f),"quota_before":before_quota,"quota_after":d04_quota(f),"emitted":f.events.slice(start),"direct_HP_write":false}
 d04_packets.append(record)
 near_number(float(f.sim.hero.hp),remaining,label+": original damage pipeline reaches requested actual HP")
 f.session.update_after_source_step()
 return record

func d04_heal_full(f: Dictionary, label: String) -> void:
 var before: float = f.sim.hero.hp
 var actual: float = f.sim.heal(float(f.sim.hero.stats.max_hp),false,{"source":"equipment41_heal_fixture","fixture":true,"purpose":label})
 d04_heals.append({"label":label,"api":"original heal","before":before,"after":f.sim.hero.hp,"actual":actual,"direct_HP_write":false})
 f.session.update_after_source_step()
 near_number(float(f.sim.hero.hp),float(f.sim.hero.stats.max_hp),label+": original healing reaches current final maxHP")

func d04_threshold() -> void:
 current_group = D04_GROUPS[0]
 var f: Dictionary = d04_start(current_group,2)
 if f.is_empty():return
 var model = f.session.ledger.model
 var status: Dictionary = model.equipment_runtime_status(D04_ITEM)
 check(owned_count(f,D04_ITEM)==2 and status.passive20=={"health_threshold":30.0,"shield_ratio":18.0,"duration":4.0},"two actual copies retain source30/18/4 unique tuning")
 var stats: Dictionary = model.equipment_effects().stats
 near_number(float(stats.get("max_hp",0.0))-float(f.baseline.equipment.stats.get("max_hp",0.0)),900.0,"two D04 static HP450 copies")
 near_number(float(stats.get("AD",0.0))-float(f.baseline.equipment.stats.get("AD",0.0)),80.0,"two D04 static AD40 copies")
 near_number(float(stats.get("lifesteal",0.0))-float(f.baseline.equipment.stats.get("lifesteal",0.0)),0.14,"two D04 static lifesteal7% copies")
 # Original naked HP is360. Two legal D04 copies raise maxHP to1260 without
 # healing, so the untouched owner begins below378. Establish this DOWNWARD
 # crossing fixture with original heal, never by assigning HP or removing any
 # unrelated shield. The other low-entry groups preserve their original HP.
 d04_heal_full(f,"threshold fixture heals through original source API before exact crossing")
 var max_hp: float = f.sim.hero.stats.max_hp
 var threshold: float = max_hp*float(status.passive20.health_threshold)*0.01
 if not check(f.sim.hero.hp>threshold and d04_raw(f).is_empty() and not d04_view(f).used_in_room,"original heal establishes above-threshold HP with unused D04 quota and no D04 shield"):dispose(f);return
 if d04_damage_to(f,threshold,"exact source30percent").is_empty():dispose(f);return
 check(f.sim.hero.hp==threshold and not d04_view(f).used_in_room and f.d04_shields.is_empty() and d04_raw(f).is_empty(),"exactly30percent is not below and consumes no room quota")
 if d04_damage_to(f,threshold-1.0,"first actual below-threshold wound").is_empty():dispose(f);return
 if not check(f.d04_shields.size()==1 and d04_receipts(f).size()==1,"two D04 copies issue exactly one original shield and command receipt"):dispose(f);return
 var raw: Dictionary = d04_raw(f)
 near_number(float(raw.amount),max_hp*0.18,"actual shield equals18percent of trigger final maxHP")
 near_number(float(raw.initial_amount),max_hp*0.18,"original shield metadata freezes trigger amount")
 near_number(float(raw.left),4.0,"actual original shield begins with four actor seconds")
 var quota: Dictionary = d04_quota(f)
 var commit: Dictionary = f.d04_original_commit
 f.sim._hero_after_incoming(float(commit.hp_before),float(commit.lost),f.d04_original_metadata)
 f.sim._hero_after_incoming(float(commit.hp_before),float(commit.lost),f.d04_original_metadata.duplicate(true))
 f.sim.emit_event("damage",{"target":f.sim.hero.actor_id,"source":"equipment41_public_fake_damage","amount":999999.0,"raw":999999.0,"absorbed":0.0,"position":f.sim.hero.position})
 check(d04_raw(f)==raw and d04_quota(f)==quota and f.d04_shields.size()==1,"repeated afterhook, borrowed original/copy metadata and public damage cannot reissue shield")
 var receipt: Dictionary = d04_receipts(f)[0]
 if d04_damage_to(f,float(f.sim.hero.hp)-1.0,"original shield absorbs then one further HP loss").is_empty():dispose(f);return
 check(d04_raw(f).is_empty() and d04_quota(f)==quota and f.d04_shields.size()==1,"actual shield consumption and another lowHP wound never refresh used room")
 var replay: Dictionary = model.command(receipt.id,receipt.request.action,receipt.request.args)
 check(replay.get("accepted",false) and replay.get("replayed",false) and d04_raw(f).is_empty(),"successful original command receipt replay cannot recreate consumed shield")
 d04_heal_full(f,"recover through actual source heal")
 if d04_damage_to(f,threshold-1.0,"heal then recross same-room threshold").is_empty():dispose(f);return
 check(d04_raw(f).is_empty() and d04_quota(f)==quota and d04_receipts(f).size()==1,"heal and real downward recross preserve same-room once quota")
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func d04_lethal() -> void:
 current_group = D04_GROUPS[1]
 var f: Dictionary = d04_start(current_group)
 if f.is_empty():return
 if d04_damage_to(f,0.0,"actual original lethal packet").is_empty():dispose(f);return
 for _tick: int in range(MAX_TERMINAL_TICKS):
  if f.session.status=="defeated":break
  step(f)
 check(f.sim.hero.hp==0.0 and f.sim.hero.dead and f.sim.phase=="true_dead","lethal source HP commit remains real true death")
 check(f.session.status=="defeated" and f.session.terminal_pending.is_empty() and f.session.fault.is_empty(),"original queued terminal reaches actual Session defeated without bypass")
 check(f.terminals.size()==1 and f.session.ledger.model.state.get("actor_dead",false),"one original death terminal updates existing ledger life state")
 check(f.d04_shields.is_empty() and d04_raw(f).is_empty() and d04_receipts(f).is_empty() and d04_quota(f).rooms.is_empty(),"lethal packet grants no shield, consumes no quota, and never revives")
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func d04_report(suite: String) -> void:
 check(d04_completed==d04_required,"all selected D04 original source groups completed")
 var report: Dictionary = {"suite":suite,"passed":failures.is_empty() and d04_completed==d04_required,"checks":checks,"failures":failures,"check_records":check_records,"partition":d04_partition,"required_groups":d04_required,"completed_groups":d04_completed,"evidence":evidence,"incoming_packets":d04_packets,"original_shields":d04_shield_records,"source_heals":d04_heals,"productionSession":true,"original_Host_factories":true,"source_damage_fixture":true,"wallet_fixture":true,"direct_HP_shield_quota_CD_writes":false,"extra_actors":false,"natural_play":false,"native_GUI":false,"production_ready":false}
 var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Cannot write D04 source result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("D04_ORIGINAL_SOURCE ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 if D04_GROUPS[0] in d04_required:d04_threshold()
 if D04_GROUPS[1] in d04_required:d04_lethal()
 d04_report("equipment41_D04_original_HP_threshold_and_terminal")
