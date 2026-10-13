extends RefCounted
## The simulation-facing adapter. No progression/reward authority lives here.
const Runtime = preload("res://scripts/combat/common_hex_runtime.gd")
const Design = preload("res://data/final_design/catalog.gd")
const MAX_DRAIN = 4096
var runtime = Runtime.new()
var _sim: WeakRef
var model: WeakRef
var settings: Dictionary = {}
var context_values: Dictionary = {}
var _last_stats: Dictionary = {}
var _draining = false
var _inside_hit = 0
var _shift_cast = 0
var _pending_finishes: Dictionary = {}
var _spatial_recorded: Dictionary = {}
var _action_origins: Dictionary = {}

func _init(sim) -> void:
 _sim = weakref(sim)

func sim(): return _sim.get_ref()

func context() -> Dictionary:
 var s = sim()
 var h = s.hero
 var effective = h.stats.duplicate()
 effective.ad = h.ad()
 # Concrete models may add temporary/passive crit without mutating projected stats.
 if h.has_method("critical_chance"): effective.crit_chance = h.critical_chance()
 # Compare movement-speed attributes, including slows/buffs, never physical displacement.
 effective.move_speed = h.speed()
 var hero = {"actor_id":h.actor_id, "hp":h.hp, "dead":h.dead, "position":h.position, "facing":h.facing, "aim_point":h.aim_point, "stats":effective}
 var friendlies: Array = []
 for ally in s.allies:
  friendlies.append({"actor_id":ally.actor_id,"hp":ally.hp,"dead":ally.dead,"position":ally.position,"stats":ally.stats})
 var kind = "ordinary"
 for enemy in s.enemies:
  if enemy.dead: continue
  if enemy.kind == "boss": kind = "boss"; break
  if enemy.kind == "elite": kind = "elite"
 var result = {"hero":hero,"enemies":s.enemies,"allies":friendlies,"room_id":s.room_id,"generation":s.encounter_generation,"run_id":"standalone","ranged":false,"gold":h.gold,"empty_slots":0,"encounter_kind":kind}
 result.merge(context_values, true)
 if model != null and model.get_ref() != null:
  var m = model.get_ref()
  result.gold = m.state.get("gold", result.gold)
  result.empty_slots = maxi(0, int(m.config.get("equipment_slots", 6)) - m.state.get("inventory", []).size())
 return result

func bind_model(progression_model) -> void:
 model = weakref(progression_model)
 sync_selected()
 refresh_stats()

func configure(options: Dictionary) -> void:
 settings = options.duplicate(true)
 sync_selected()
 refresh_stats()

func sync_selected() -> void:
 var options = settings.duplicate(true)
 var weak_sim = _sim
 options.clip_projectile = func(a, b): return weak_sim.get_ref()._move_clipped(a, b, 0.05)
 if model != null and model.get_ref() != null:
  var weak_model = model
  options.parameter_value = func(id, token, _base): return weak_model.get_ref().hex_parameter(id, token)
 runtime.configure(sim().hero.hexes, options)

func ensure_combat() -> void:
 var s = sim()
 if s.phase == "combat" and (not runtime.combat or runtime.generation != s.encounter_generation or runtime.room_id != s.room_id): begin_room()

func begin_room() -> void:
 _pending_finishes.clear()
 _spatial_recorded.clear()
 _action_origins.clear()
 _shift_cast = 0
 sync_selected()
 runtime.begin_room(context())
 refresh_stats()
 drain()

func end_room() -> void:
 runtime.end_room()
 _pending_finishes.clear()
 _shift_cast = 0

func set_projected(projected: Dictionary) -> void:
 var h = sim().hero
 var mapping = {"AD":"ad","AP":"ap","defense":"defence","hp_regen":"regen","cooldown_reduction":"cdr"}
 for key in projected:
  var target: String = mapping.get(key, key)
  h.projected_base_stats[target] = projected[key]
 _last_stats.clear()
 refresh_stats(false)

func refresh_stats(detect_external_changes: bool = true) -> void:
 var h = sim().hero
 # Fixture/debug direct stat mutations are treated as new projected inputs, never multiplied twice.
 if detect_external_changes:
  for key in h.stats:
   if key in ["common_damage_multiplier","model_scale","attack_range"]: continue
   if _last_stats.is_empty() or h.stats[key] != _last_stats.get(key, h.stats[key]): h.projected_base_stats[key] = h.stats[key]
 var projected = runtime.project_stats(h.projected_base_stats, context())
 h.stats = projected
 h.hp = minf(h.hp, h.stats.max_hp)
 _last_stats = projected.duplicate(true)

func start_action(slot: String, cast_id: int, origin: Vector3) -> void:
 ensure_combat()
 var s = sim()
 var candidate: String = s.hero.loadout.get(slot, slot)
 var move = false
 if not s.has_method("common_action_metadata"):
  move = slot == "shift" or candidate in ["q1","e2","r2"] or (candidate == "e1" and s.hx("welcome"))
 var action = {"action_id":str(cast_id),"cast_id":cast_id,"hero_id":"xuanlei","candidate":candidate,"slot":slot,"active_skill":slot in ["q","e","r"],"ultimate":slot == "r","active_movement":move}
 if s.has_method("common_action_metadata"): action.merge(s.common_action_metadata(slot),true)
 _action_origins[cast_id] = origin
 runtime.action_start(action, context())
 if slot == "shift": _shift_cast = cast_id
 drain()

func base_cooldown(slot: String, amount: float) -> float:
 var candidate: String = sim().hero.loadout.get(slot, slot)
 if sim().has_method("common_cooldown_metadata"):
  return runtime.skill_cooldown(amount,sim().common_cooldown_metadata(slot))
 if sim().has_method("common_action_metadata"):
  return runtime.skill_cooldown(amount,sim().common_action_metadata(slot))
 return runtime.skill_cooldown(amount, {"slot":slot,"active_skill":slot in ["q","e","r"],"ultimate":slot == "r","active_movement":candidate in ["q1","e2"] or (candidate == "e1" and sim().hx("welcome"))})

func complete_action(cast_id: int, cancelled: bool = false, wait_for_motion: bool = false) -> void:
 if wait_for_motion:
  _pending_finishes[cast_id] = true
  return
 var ending={"action_id":str(cast_id),"cast_id":cast_id,"cancelled":cancelled}
 # Legacy runtime auto-completes movement before cancellation. New adapters must
 # not grant movement rewards to an explicitly cancelled/unrealized cast.
 if cancelled and sim().has_method("common_action_metadata"): ending["active_movement"]=false
 # Wind multi-stage E1 can end on mark expiry without any displacement. Actual
 # movement callbacks, not the cooldown taxonomy, authorize G07 for this adapter.
 if sim().has_method("common_requires_explicit_movement") and sim().common_requires_explicit_movement(): ending["active_movement"]=false
 runtime.action_end(ending, context())
 _pending_finishes.erase(cast_id)
 refresh_stats()
 drain()

func movement_complete(cast_id: int) -> void:
 runtime.displacement_completed({"action_id":str(cast_id),"cast_id":cast_id,"active_movement":true},context())
 refresh_stats()
 drain()

func dash_complete() -> void:
 if _shift_cast <= 0: return
 complete_action(_shift_cast)
 _shift_cast = 0

func ultimate_ready(cast_id: int) -> void:
 runtime.ultimate_presentation_ended({"action_id":str(cast_id),"cast_id":cast_id},context())
 refresh_stats()
 drain()

func damage_metadata(source: String, cast_id: int, supplied: Dictionary) -> Dictionary:
 var s = sim()
 var result = supplied.duplicate(true)
 var active_skill = source in ["q1","q2","q3","q3_collision","e1","e2","e2_wall","r1","r2_charge","r2_wall","r2_finish"]
 # Concrete adapters provide only their own taxonomy; supplied packet metadata wins.
 if s.has_method("common_damage_metadata"):
  result.merge(s.common_damage_metadata(source),false)
 result.merge({"source":source,"cast_id":cast_id,"action_id":str(cast_id),"active_skill":active_skill,"basic_attack":source in ["attack","dash_attack"],"direct":not source.begins_with("dot_"),"area":source in ["attack","dash_attack","q1","q3","e1","r1","r2_wall","r2_finish"],"position":s.hero.position,"cast_origin":_action_origins.get(cast_id,s.hero.position),"direction":s.hero.facing,"hex_generated":source.begins_with("hex_") or source.begins_with("common_") or source == "q1_echo"},false)
 return result

func before_hit(enemy: Dictionary, amount: float, source: String, cast_id: int, is_true: bool, critical: bool, metadata: Dictionary) -> Dictionary:
 ensure_combat()
 refresh_stats()
 var event = damage_metadata(source, cast_id, metadata)
 event.target = enemy
 event.amount = amount
 event.damage_type = "true" if is_true else "ordinary"
 event.critical = critical
 if event.get("basic_attack",false) or critical: event.crit_rolled = true
 return runtime.before_damage(event, context())

func after_hit(event: Dictionary, actual: float) -> void:
 event.effective_damage = actual
 runtime.after_hit(event, context())

func killed(enemy: Dictionary, source: String, cast_id: int) -> void:
 runtime.enemy_died({"target":enemy,"participated":true,"source":source,"cast_id":cast_id},context())
 refresh_stats()

func record_spatial(cast_id: int, segment_id: String, amount: float, at: Vector3, shape: Dictionary, extra: Dictionary = {}) -> void:
 var key = "%s:%s:%s" % [cast_id,segment_id,extra.get("occurrence",0)]
 var original_target = str(extra.get("original_target_id",""))
 # Keep target-specific hero final multipliers out of the shared fallback/G25
 # budget. Surviving originals replay their captured multiplier; new targets do not.
 var hero_final = maxf(Runtime.EPS,float(extra.get("hero_final_multiplier",1.0)))
 var bonus = float(extra.get("cast_bonus_final",0.0))/hero_final
 var base_amount = maxf(0.0,amount/hero_final-bonus)
 if _spatial_recorded.has(key):
  # Preserve distinct nominal hit/critical outcomes for surviving original targets.
  # A shared G25 full-cast budget remains one budget when replay queries new targets.
  if runtime.actions.has(str(cast_id)):
   for captured in runtime.actions[str(cast_id)].segments:
    if str(captured.get("capture_key","")) != key: continue
    if not original_target.is_empty():
     captured.target_amounts[original_target]=base_amount
     captured.target_criticals[original_target]=extra.get("critical",false)
     captured.target_final_multipliers[original_target]=hero_final
    if str(shape.get("kind",""))=="recorded_path": captured.shape=shape.duplicate(true)
    captured.cast_bonus_total+=bonus
  return
 _spatial_recorded[key] = true
 var record = {"kind":"damage","independent":true,"target_mode":"spatial","segment_id":segment_id,"amount":base_amount,"position":at,"shape":shape,"capture_key":key,"target_amounts":{},"target_criticals":{},"target_final_multipliers":{},"cast_bonus_total":bonus}
 record.merge(extra,true)
 if not original_target.is_empty():
  record.target_amounts[original_target]=base_amount
  record.target_criticals[original_target]=extra.get("critical",false)
  record.target_final_multipliers[original_target]=hero_final
 runtime.record_segment(cast_id,record,context())

func record_bound(cast_id: int, segment_id: String, target: Dictionary, nominal: float, at: Vector3, extra: Dictionary = {}) -> void:
 var record = {"kind":"damage","independent":true,"target_mode":"bound","segment_id":segment_id,"target_ids":[target.actor_id],"amount":nominal,"position":at}
 record.merge(extra,true)
 runtime.record_segment(cast_id,record,context())

func shield_metadata(source: String, amount: float, duration: float, supplied: Dictionary = {}) -> Dictionary:
 var result = {"amount":amount,"initial_amount":amount,"left":duration,"owner_id":sim().hero.actor_id,"source":source,"source_hex":source if source.begins_with("common_") else "","source_cast":0,"no_rescue_charge":source == "common_g13"}
 result.merge(supplied,true)
 return result

func absorbed(holder, shield: Dictionary, absorbed_amount: float, reason:String="enemy_damage") -> void:
 if absorbed_amount <= 0: return
 runtime.shield_absorbed({"target_id":holder.actor_id,"shield":shield,"absorbed":absorbed_amount},context())
 if float(shield.amount) <= Runtime.EPS:
  runtime.shield_broken({"target_id":holder.actor_id,"position":holder.position,"shield":shield,"absorbed":absorbed_amount,"remaining":shield.amount,"reason":reason},context())

func healed(target, actual: float, metadata: Dictionary) -> void:
 var event = metadata.duplicate(true)
 event.merge({"owner_id":sim().hero.actor_id,"target_id":target.actor_id,"effective_heal":actual},false)
 runtime.healed(event,context())

func incoming(amount: float, direct: bool) -> float:
 ensure_combat()
 return runtime.before_damage({"amount":amount,"incoming":true,"direct":direct,"stage":"hp_commit"},context()).amount

func begin_tick(world_dt: float, actor_dt: float = -1.0) -> void:
 ensure_combat()
 runtime.begin_tick(world_dt,actor_dt)
 refresh_stats()

func tick(dt: float, actor_dt: float = -1.0) -> void:
 ensure_combat()
 refresh_stats()
 for cast_id in _pending_finishes.keys():
  var outstanding = false
  for enemy in sim().enemies:
   if not enemy.get("push",{}).is_empty() and int(enemy.push.get("cast_id",-1)) == int(cast_id): outstanding = true
  if not outstanding: complete_action(int(cast_id))
 runtime.tick(dt,context(),actor_dt)
 refresh_stats()
 drain()

func drain() -> void:
 if _draining or _inside_hit > 0: return
 _draining = true
 var count = 0
 while true:
  var batch = runtime.drain_events()
  if batch.is_empty(): break
  for event in batch:
   count += 1
   if count > MAX_DRAIN:
    push_error("Common Hex effect drain exceeded bounded work budget")
    _draining = false
    return
   if int(event.generation) != sim().encounter_generation or event.room_id != sim().room_id: continue
   _apply(event)
 _draining = false

func _apply(event: Dictionary) -> void:
 var s = sim()
 var target = _friendly(str(event.get("target_id","")))
 var applied_amount:float=-1.0
 match str(event.kind):
  "damage":
   var enemy: Dictionary = s.enemy_by_id(str(event.target_id))
   if not enemy.is_empty(): s.damage_enemy(enemy,float(event.amount),str(event.source),int(event.get("cast_id",0)),event.get("damage_type", "ordinary") == "true",bool(event.get("critical",false)),event)
  "execute":
   var enemy: Dictionary = s.enemy_by_id(str(event.target_id))
   if not enemy.is_empty() and not enemy.dead and s.ordinary(enemy): s._kill_enemy(enemy,str(event.source),int(event.get("cast_id",0)))
  "heal":
   applied_amount=s.heal_actor(target,float(event.amount),event) if target != null else 0.0
  "shield":
   if target != null:
    var id = "%s:%s" % [event.source,event.event_id]
    target.shields[id] = shield_metadata(str(event.source),event.amount,event.duration,event)
    s.emit_event("shield",{"target":target.actor_id,"source":event.source,"amount":event.amount,"duration":event.duration,"owner_id":event.owner_id,"initial_amount":event.initial_amount,"cast_id":event.cast_id})
  "health_cost":
   if s.has_method("apply_committed_health_loss"):applied_amount=s.apply_committed_health_loss(float(event.amount),true,event)
   else:s.hero.hp = maxf(1.0,s.hero.hp-float(event.amount))
  "health_debt":
   if s.has_method("apply_committed_health_loss"):applied_amount=s.apply_committed_health_loss(float(event.amount),false,event)
   else:
    s.hero.hp = maxf(0.0,s.hero.hp-float(event.amount))
    if s.hero.hp<=0: s._common_true_death()
  "reset_cooldowns":
   if s.has_method("common_reset_cooldowns"):
    s.common_reset_cooldowns(event.slots)
   else:
    for slot in event.slots:
     if int(s.hero.ranks.get(slot,0)) > 0: s.hero.cooldowns[slot] = 0.0
    if s.hero.ranks.q>0 and s.hero.loadout.q=="q2" and s.hx("double_chain"):
     s.chain_charges=int(s.hv("double_chain"));s.chain_recharges.clear()
  "enemy_modifiers":
   var enemy: Dictionary=s.enemy_by_id(str(event.target_id))
   if not enemy.is_empty():
    if not enemy.has("common_base_radius"): enemy.common_base_radius=enemy.radius
    enemy.radius=float(enemy.common_base_radius)*float(event.modifiers.collision_scale)
    enemy.common_model_scale=event.modifiers.model_scale
    enemy.common_damage_multiplier=event.modifiers.damage_multiplier
    enemy.common_knockback_resistance_multiplier=event.modifiers.knockback_resistance_multiplier
  "knockback":
   var enemy: Dictionary=s.enemy_by_id(str(event.target_id))
   if not enemy.is_empty() and s.ordinary(enemy): s.push_enemy(enemy,event.direction,event.distance,str(event.source),int(event.cast_id))
 var presentation = event.duplicate(true)
 if applied_amount>=0:presentation["applied_amount"]=applied_amount
 presentation.erase("kind")
 s.emit_event("common_hex_"+str(event.kind),presentation)

func _friendly(id: String):
 if sim().hero.actor_id == id: return sim().hero
 for actor in sim().allies:
  if actor.actor_id == id: return actor
 return null

func potion_used(item_id: String) -> void:
 ensure_combat()
 runtime.potion_used(context())
 drain()
 sim().emit_event("potion_used",{"item_id":item_id,"position":sim().hero.position,"source":"consumable"})

func status_effects() -> Array:
 var result: Array = []
 var now = runtime.actor_time
 for entry in [["g07",runtime.dash_until,runtime.dash_stacks],["g09",runtime.final_until,1],["g10",runtime.soul_speed_until,1],["g19",runtime.boss_until,1]]:
  if runtime.active(entry[0]) and float(entry[1]) > now:
   var definition = Design.hex_definition("common_"+entry[0])
   result.append({"id":definition.id,"name":definition.name,"kind":"buff","stacks":entry[2],"remaining":float(entry[1])-now,"description":definition.description})
 if runtime.active("g18") and runtime.replay_charges>0:
  var definition:Dictionary=Design.hex_definition("common_g18")
  result.append({"id":"common_g18","name":definition.name,"kind":"buff","stacks":runtime.replay_charges,"remaining":-1.0,"description":"已储存%d次残响；下一次可复现的普通技能结算后消耗一次"%runtime.replay_charges})
 if runtime.active("g04") and runtime.growth>0: result.append({"id":"common_g04","name":"越战越大","kind":"buff","stacks":runtime.growth,"remaining":-1.0,"description":"普通敌人参与击杀成长；真正死亡损失层数"})
 if not runtime.debt.is_empty(): result.append({"id":"common_g29","name":"缓伤酒","kind":"debuff","stacks":0,"remaining":runtime.debt[0].duration,"description":"已结算的延后生命损失；安全阶段冻结"})
 return result
