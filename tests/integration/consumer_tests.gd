extends RefCounted
const Model = preload("res://scripts/integration/run_model.gd")
const Consumers = preload("res://scripts/integration/consumers.gd")
const Sim = preload("res://scripts/combat/combat_sim.gd")
const Room = preload("res://scripts/integration/room.gd")
var checks := {}
var serial := 0
func check(label: String, ok: bool) -> void:
 checks[label] = ok
func command(model: RefCounted, action: String, args := {}) -> Dictionary:
 serial += 1
 return model.command("test-%d"%serial,action,args)
func fresh() -> Array:
 var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
 var model = Model.new(defs,"fengli")
 model.set_supported_hooks(Consumers.HOOKS)
 command(model,"reward_minion",{"event_id":"fixture-capital","gold":100000,"xp":0})
 command(model,"enter_level",{"combat_level_id":"fixture1"})
 var sim = Sim.new()
 sim.phase = "victory"
 sim.hero.hp = 10.0
 sim.hero.cooldowns.q = 4.0
 return [model,sim,Consumers.new()]
func run() -> Dictionary:
 var f := fresh()
 var m = f[0]; var sim = f[1]; var c = f[2]
 for i in range(5): check("normal_buy_%d"%i,command(m,"buy",{"item":"normal_tonic"}).accepted)
 check("normal_5_in_one_slot",m.snapshot().inventory.size()==1 and m.snapshot().inventory[0].count==5)
 check("normal_6_rejected",not command(m,"buy",{"item":"normal_tonic"}).accepted)
 check("holding_mutex",not command(m,"buy",{"item":"special_tonic"}).accepted)
 var uid: int = m.snapshot().inventory[0].uid
 var before: Dictionary = m.snapshot()
 sim.phase = "combat"
 check("unsafe_consume_atomic",not c.use_recovery(sim,m,"unsafe",uid).accepted and m.snapshot()==before and sim.hero.hp==10)
 sim.phase = "victory"
 var r: Dictionary = c.use_recovery(sim,m,"normal",uid)
 check("normal_18percent_actual_HP",r.accepted and is_equal_approx(sim.hero.hp,53.2) and sim.hero.cooldowns.q==4)
 var after: Dictionary = m.snapshot()
 c.use_recovery(sim,m,"normal",uid)
 check("duplicate_no_heal_consume",is_equal_approx(sim.hero.hp,53.2) and m.snapshot()==after)
 check("rebound_coordinator_no_heal",not Consumers.new().use_recovery(sim,m,"normal",uid).accepted and is_equal_approx(sim.hero.hp,53.2))
 check("consume_clears_undo",not command(m,"undo_shop").accepted)
 command(m,"sell",{"uid":uid})
 command(m,"buy",{"item":"special_tonic"})
 var special_uid: int = m.snapshot().inventory[0].uid
 before=m.snapshot()
 check("sell_switch_cannot_bypass_mutex",not c.use_recovery(sim,m,"switch",special_uid).accepted and m.snapshot()==before and is_equal_approx(sim.hero.hp,53.2))
 command(m,"enter_level",{"combat_level_id":"fixture2"})
 for i in range(2): command(m,"buy",{"item":"special_tonic"})
 sim.hero.hp=10
 check("special_first",c.use_recovery(sim,m,"s1",special_uid).accepted and sim.hero.hp==82)
 special_uid=m.snapshot().inventory[0].uid
 check("special_second",c.use_recovery(sim,m,"s2",special_uid).accepted and sim.hero.hp==154)
 before=m.snapshot();special_uid=m.snapshot().inventory[0].uid
 check("special_third_atomic_reject",not c.use_recovery(sim,m,"s3",special_uid).accepted and m.snapshot()==before and sim.hero.hp==154)
 sim.phase="true_dead"; sim.hero.dead=true
 check("dead_no_use",not c.use_recovery(sim,m,"dead",special_uid).accepted and m.snapshot()==before)
 sim.phase="victory";sim.hero.dead=false
 command(m,"enter_level",{"combat_level_id":"fixture3"})
 check("new_room_reset_two_uses",m.snapshot().special_uses==0 and c.use_recovery(sim,m,"s-new",special_uid).accepted and m.snapshot().special_uses==1)
 sim.free()
 f=fresh();m=f[0];sim=f[1];c=f[2]
 for i in range(6): command(m,"buy",{"item":"mainspring"})
 check("six_slots_block_potion",not command(m,"buy",{"item":"normal_tonic"}).accepted and m.occupied_slots()==6)
 c.sync_stats(sim,m)
 check("actual_AS_cap_2_5",sim.hero.attack_speed()==2.5)
 sim.phase="combat";sim.ai_enabled=false;sim.auto_finish=false
 sim.request_action("attack",Vector3.ZERO)
 check("actual_attack_interval_at_cap",is_equal_approx(sim.hero.cooldowns.attack,0.4))
 sim.free()
 f=fresh();m=f[0];sim=f[1];c=f[2]
 var old_hp: float=sim.hero.hp
 command(m,"buy",{"item":"blood_crystal"}); c.sync_stats(sim,m)
 check("HP_buy_no_heal",sim.hero.stats.max_hp==340 and sim.hero.hp==old_hp and sim.hero.cooldowns.q==4)
 command(m,"sell",{"uid":m.snapshot().inventory[0].uid}); c.sync_stats(sim,m)
 command(m,"undo_shop"); c.sync_stats(sim,m)
 check("HP_sell_undo_no_heal_CD",sim.hero.hp==old_hp and sim.hero.cooldowns.q==4)
 command(m,"buy",{"item":"cooling_core"}); c.sync_stats(sim,m)
 check("CDR_preserves_existing_CD",sim.hero.cooldowns.q==4 and sim.hero.stats.cdr==0.06)
 sim.phase="combat";sim.ai_enabled=false;sim.auto_finish=false
 check("CDR_new_dash_actual",sim.request_action("shift",Vector3.ZERO).accepted and is_equal_approx(sim.hero.cooldowns.shift,3.008))
 sim.free()
 # Explicit alternate numeric test initial, same consumer and schema; no new production flag.
 f=fresh();m=f[0];sim=f[1];c=f[2]
 m.config.items.cooling_core.stats.cooldown_reduction=0.4
 command(m,"buy",{"item":"cooling_core"});command(m,"buy",{"item":"cooling_core"});c.sync_stats(sim,m)
 check("actual_CDR_cap_65percent",sim.hero.stats.cdr==0.65)
 sim.phase="combat";sim.ai_enabled=false;sim.auto_finish=false
 sim.request_action("shift",Vector3.ZERO)
 check("cap_applies_new_dash",is_equal_approx(sim.hero.cooldowns.shift,1.12))
 sim.free()
 f=fresh();m=f[0];sim=f[1];c=f[2]
 command(m,"hex_open",{"milestone":1})
 var offer: Dictionary=m.snapshot().offers["1"]
 var valid := true
 for id in offer.slots:
  valid=valid and m.support(m.config.hexes[id]).supported
 check("offered_only_supported_numeric_hooks",valid and offer.slots.size()==4)
 command(m,"hex_select",{"milestone":1,"slot":0});c.sync_stats(sim,m)
 var before_hex: Dictionary=m.snapshot()
 check("hex_select_once",not command(m,"hex_select",{"milestone":1,"slot":1}).accepted and m.snapshot()==before_hex)
 check("hex_projection_has_real_consumer",not m.aggregate_effects().stats.is_empty() and (sim.hero.stats.ad>32 or sim.hero.stats.attack_speed>1.7 or sim.hero.stats.max_hp>240 or sim.hero.stats.cdr>0))
 check("hex_no_free_HP_CD",sim.hero.hp==10 and sim.hero.cooldowns.q==4)
 sim.free()
 var defs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
 for seed_value in range(1,65):
  var seeded=Model.new(defs,"fengli",seed_value)
  seeded.set_supported_hooks(Consumers.HOOKS)
  var drawn: Dictionary=command(seeded,"hex_open",{"milestone":1})
  check("small_pool_hero_slot_seed_%d"%seed_value,drawn.accepted and seeded.config.hexes[seeded.snapshot().offers["1"].slots[3]].hero=="fengli")
 # Independent action-state fixture: execute actual ability state machines, not fake flags.
 sim=Sim.new();sim.ai_enabled=false;sim.auto_finish=false
 var room=Room.new();room.simulation=sim
 check("E3_cast_actual",sim.request_action("e",Vector3.ZERO).accepted)
 check("E3_active_not_ready",room._action_status("e").begins_with("持续中"))
 check("E3_recast_actual_rejection",not sim.request_action("e",Vector3.ZERO).accepted)
 sim.free();sim=Sim.new();sim.ai_enabled=false;sim.auto_finish=false;room.simulation=sim
 sim.hero.loadout.r="r2"
 check("R2_cast_actual",sim.request_action("r",Vector3.ZERO).accepted)
 check("R2_presentation_locked",room._action_status("r")=="动作锁定")
 for i in range(60):sim.step(0.02)
 check("R2_recast_not_ready",room._action_status("r").begins_with("可重施"))
 sim.end_encounter("victory")
 check("frozen_actual_return_and_label",room._action_status("r")=="战后冻结" and sim.request_action("r",Vector3.ZERO).reason=="encounter_frozen")
 room.simulation=null;room.free();sim.free()
 var failures:=[]
 for name in checks:
  if not checks[name]: failures.append(name)
 return {"checks":checks,"failures":failures,"scope":"controlled model/combat fixtures, not natural playthrough"}
