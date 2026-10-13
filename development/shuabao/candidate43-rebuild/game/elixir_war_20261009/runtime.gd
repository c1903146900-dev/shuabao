extends RefCounted
## War elixir data contract. Authentication remains the original emitted
## death witness plus the bound Model command; this helper is not authority.
const ITEM_ID := "elixir:01"
const PASSIVE_ID := "elixir:01.on_kill"
const DeathContract = preload("res://equipment_training_20261009/task02.gd")
const BUFF_KEY := "elixir_war_on_kill"
const BUFF_SCHEMA := "war_runtime_owner_buff_v1"

static func propose(selection: Dictionary, previous: Dictionary, claims: Dictionary, context: Dictionary, evidence: Dictionary) -> Dictionary:
 if not _context(context) or not context.owner_alive: return _deny("war_live_original_owner_clock_required")
 if not _true(selection.get("equipped")) or selection.get("item_id") != ITEM_ID or selection.get("passive_id") != PASSIVE_ID or not selection.get("owned_copies") is int or int(selection.owned_copies) <= 0 or not selection.get("tuning") is Dictionary or not valid_tuning(selection.tuning): return _deny("war_not_equipped")
 var view: Dictionary = inspect(previous,context)
 if not view.get("eligible",false): return view
 if claims.size() != 2 or claims.get("scope") != context.scope or not claims.get("by_target") is Dictionary: return _deny("war_current_claim_scope_required")
 var used: Dictionary = {}
 for claim_target: Variant in claims.by_target:
  var id: Variant = claims.by_target[claim_target]
  if not _text(claim_target) or not _text(id) or used.has(id): return _deny("war_invalid_death_claim")
  used[id] = true
 if evidence.get("schema") != DeathContract.SCHEMA or not evidence.get("event") is Dictionary or not evidence.get("original_target") is Dictionary or not evidence.get("witness") is Dictionary: return _deny("war_original_g02_death_contract_required")
 var event: Dictionary = evidence.event
 var target: Dictionary = evidence.original_target
 var witness: Dictionary = evidence.witness
 for flag: String in DeathContract.FLAGS:
  if not _true(witness.get(flag)): return _deny("war_source_verification_required:" + flag)
 if witness.get("scope") != context.scope or witness.get("proof") not in ["original_damage_death","original_p1_atomic_death"] or not witness.get("death_serial") is int or int(witness.death_serial) <= 0: return _deny("war_original_death_scope_required")
 if event.get("kind") != "kill" or event.get("credit") != "solo_lethal" or not _text(event.get("source")) or not event.get("cast_id") is int or int(event.cast_id) < 0: return _deny("war_actual_solo_death_required")
 if witness.get("source") != event.source or witness.get("cast_id") != event.cast_id: return _deny("war_original_source_mismatch")
 if witness.proof == "original_p1_atomic_death" and (event.source != "yanguizhou_p1" or not _true(event.get("p1_supplement"))): return _deny("war_original_p1_receipt_required")
 if not _text(target.get("actor_id")) or event.get("target") != target.actor_id or witness.get("target") != target.actor_id or not _true(target.get("dead")) or not _number(target.get("hp")) or float(target.hp) != 0.0: return _deny("war_original_target_required")
 for record: Dictionary in [event,target]:
  if not record.get("generation") is int or record.generation != context.scope.generation or record.get("room_id") != context.scope.room_id: return _deny("war_old_source_scope")
 var death_id: String = JSON.stringify([context.scope.run_id,context.scope.generation,context.scope.room_id,witness.death_serial,target.actor_id])
 if claims.by_target.has(target.actor_id) or used.has(death_id): return _deny("war_death_already_claimed")
 var expiry: float = float(context.now)+float(selection.tuning.duration)
 if not is_finite(expiry) or expiry <= float(context.now): return _deny("war_unrepresentable_expiry")
 var buff: Dictionary = {"schema":BUFF_SCHEMA,"passive_id":PASSIVE_ID,"run_id":context.scope.run_id,"actor_id":context.scope.actor_id,"owner_token":context.owner_token,"clock_token":context.clock_token,"granted_at":float(context.now),"expires_at":expiry,"duration":float(selection.tuning.duration),"move_fraction":float(selection.tuning.move_bonus)*0.01,"attack_speed_fraction":float(selection.tuning.attack_speed_bonus)*0.01,"last_death_commit_id":death_id,"origin_scope":context.scope.duplicate(true),"battle_id":context.battle_id}
 return {"eligible":true,"reason":"","claim_to_add":{"target_id":target.actor_id,"death_commit_id":death_id},"buff":buff,"refreshes_existing":bool(view.active),"prior_buff":previous.duplicate(true)}

static func inspect(buff: Dictionary, context: Dictionary) -> Dictionary:
 if not _context(context): return _deny("war_original_owner_clock_required")
 if buff.is_empty(): return {"eligible":true,"active":false,"move_fraction":0.0,"attack_speed_fraction":0.0,"remaining":0.0}
 if not _buff(buff): return _deny("war_invalid_buff_record")
 if buff.run_id != context.scope.run_id or buff.actor_id != context.scope.actor_id or buff.owner_token != context.owner_token or buff.clock_token != context.clock_token: return _deny("war_wrong_buff_owner_run_or_clock")
 if buff.get("battle_id") != context.battle_id: return _deny("war_wrong_battle")
 if float(context.now) < float(buff.granted_at): return _deny("war_owner_clock_rewound")
 # Whole elixir lifetime is additionally checked by the bound Model.
 # No remaining seconds survive its battle end or effect replacement.
 var active: bool = context.owner_alive and float(context.now) < float(buff.expires_at)
 return {"eligible":true,"active":active,"move_fraction":float(buff.move_fraction) if active else 0.0,"attack_speed_fraction":float(buff.attack_speed_fraction) if active else 0.0,"remaining":maxf(0.0,float(buff.expires_at)-float(context.now)) if context.owner_alive else 0.0}

static func _context(context: Dictionary) -> bool:
 return _text(context.get("battle_id")) and context.get("scope") is Dictionary and DeathContract.valid_scope(context.scope) and _text(context.get("owner_token")) and _text(context.get("clock_token")) and context.get("clock") == "original_common_actor_time" and _number(context.get("now")) and float(context.now) >= 0.0 and context.get("owner_alive") is bool
static func _buff(buff: Dictionary) -> bool:
 if buff.get("schema") != BUFF_SCHEMA or buff.get("passive_id") != PASSIVE_ID: return false
 if not buff.get("origin_scope") is Dictionary or not DeathContract.valid_scope(buff.origin_scope): return false
 if buff.origin_scope.run_id != buff.get("run_id") or buff.origin_scope.actor_id != buff.get("actor_id"): return false
 for key: String in ["run_id","actor_id","owner_token","clock_token","last_death_commit_id"]:
  if not _text(buff.get(key)): return false
 for key: String in ["granted_at","expires_at","duration","move_fraction","attack_speed_fraction"]:
  if not _number(buff.get(key)) or float(buff[key]) < 0.0: return false
 return float(buff.duration) > 0.0 and float(buff.expires_at) > float(buff.granted_at) and float(buff.expires_at) == float(buff.granted_at)+float(buff.duration) and float(buff.move_fraction) <= 1.0 and float(buff.attack_speed_fraction) <= 1.0
static func _true(v: Variant) -> bool:
 return v is bool and v
static func _text(v: Variant) -> bool:
 return v is String and not str(v).strip_edges().is_empty()
static func _number(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v))
static func _deny(reason: String) -> Dictionary:
 return {"eligible":false,"reason":reason}

static func valid_tuning(tuning: Dictionary) -> bool:
 if tuning.size() != 3: return false
 return _number(tuning.get("move_bonus")) and float(tuning.move_bonus) == 0.0 and _number(tuning.get("attack_speed_bonus")) and float(tuning.attack_speed_bonus) >= 0.0 and float(tuning.attack_speed_bonus) <= 100.0 and _number(tuning.get("duration")) and float(tuning.duration) > 0.0
