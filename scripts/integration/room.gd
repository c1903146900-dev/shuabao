extends "res://scripts/combat/arena.gd"
## Two repeating room layouts with authoritative rewards. All reward values are prototype initials.
const Bridge = preload("res://scripts/integration/ledger_bridge.gd")
const CombatHUD = preload("res://scripts/ui/progression_hud.gd")
const Controller = preload("res://scripts/ui/progression_controller.gd")
var consumers = preload("res://scripts/integration/consumers.gd").new()
var controller: RefCounted
var room_number := 0
var run_id := ""
var last_action_receipt := {}
var action_serial := 0
var terminal_seen := {}
var reward_errors := []
const REWARD = {"gold":150,"xp":60} # Tunable prototype reward per minion; not a historical design fact.
var ledger: RefCounted
var live_hud: Control
var start_button: Button
var help_text: Label
var attacking := false
var rescue_space_latched := false
var enter_start_keys := {}
var phase_seen := ""
var motion := {}
var hero_clip := {}
var run_serial := 0

func _ready() -> void:
 hero_visual = preload("res://assets/fengli/fengli.glb")
 minion_visual = preload("res://assets/arena/enemies/minion.glb")
 elite_visual = preload("res://assets/arena/enemies/elite.glb")
 boss_visual = preload("res://assets/arena/enemies/boss.glb")
 super._ready()
 hud.hide()
 var layer := CanvasLayer.new()
 layer.name = "IntegratedHUD"
 add_child(layer)
 live_hud = CombatHUD.new()
 layer.add_child(live_hud)
 controller = Controller.new()
 controller.bind(ledger.model,live_hud,ledger.definitions,{"hex_enabled":true,"source_label":"实战成长 · 原型初值","content_label":"原型：AD/攻速/生命上限/冷却缩减；仅数值海克斯；锻体未开放"})
 controller.combat_request.connect(_request)
 controller.command_completed.connect(_growth_completed)
 start_button = Button.new()
 start_button.text = "进入第1房"
 start_button.position = Vector2(510,24)
 start_button.size = Vector2(240,42)
 live_hud.add_child(start_button)
 start_button.pressed.connect(start_room)
 live_hud.modal_changed.connect(_modal_boundary)
 help_text = Label.new()
 help_text.text = "WASD 移动 · 左键攻击 · Q/E/R 技能 · Shift 冲刺 · K 修习\n每敌150金/60经验 · P补给：药品/四属性装备/数值海克斯 · 两种房间循环"
 help_text.position = Vector2(350,78)
 help_text.add_theme_font_size_override("font_size",14)
 live_hud.add_child(help_text)
 _present()
 print("SHUABAO_INTEGRATION_READY checkpoint=3")

func new_run() -> void:
 # F5 is now an explicit same-room retry, never a fresh ledger.
 if is_instance_valid(simulation):
  retry_room()
  return
 for view in views.values(): view.queue_free()
 views.clear()
 for effect in effects: effect.node.queue_free()
 effects.clear()
 held_keys.clear()
 attacking = false
 rescue_space_latched = false
 motion.clear()
 hero_clip.clear()
 run_serial += 1
 ledger = Bridge.new()
 run_id = "run-%d" % Time.get_ticks_usec()
 room_number = 0
 simulation = Sim.new()
 simulation.progression = ledger
 simulation.hero.xp_progress = 0.0
 simulation._sync_loadout_from_ledger()
 simulation.phase = "preparation"
 simulation.name = "CombatSimulation"
 add_child(simulation)
 simulation.combat_event.connect(_on_combat_event)
 simulation.encounter_finished.connect(_encounter_finished)
 phase_seen = "preparation"
 _sync_views(0)
 if is_instance_valid(live_hud):
  live_hud.close_panels()
  _present()

func start_room() -> void:
 if simulation.phase not in ["preparation","victory"]: return
 room_number += 1
 var id := "%s/room-%d" % [run_id,room_number]
 var entered: Dictionary = ledger.command("enter_level",{"combat_level_id":id})
 if not entered.ok:
  room_number -= 1
  return
 var roster: Array = []
 var positions: Array = [Vector3(-1,0,2),Vector3(1,0,1),Vector3(0,0,-1)] if room_number%2 else [Vector3(-2,0,1),Vector3(2,0,1),Vector3(0,0,-2)]
 for pos in positions: roster.append({"kind":"minion","position":pos})
 simulation.hero.position = Vector3(0,0,5)
 simulation.hero.move_intent = Vector3.ZERO
 var result: Dictionary = simulation.begin_encounter(id,roster)
 assert(result.accepted)
 held_keys.clear()
 attacking = false
 phase_seen = "combat"
 _present()

func retry_room() -> void:
 if simulation.phase != "true_dead": return
 # Explicit prototype retry: same surviving enemies/reward IDs, 35% HP; keep CD/ledger.
 ledger.command("life_state",{"dead":false})
 ledger.begin_encounter()
 simulation.hero.dead = false
 simulation.hero.death_state = "alive"
 simulation.hero.hp = simulation.hero.stats.max_hp*0.35
 simulation.hero.position = Vector3(0,0,5)
 simulation.hero.move_intent = Vector3.ZERO
 simulation.phase = "combat"
 held_keys.clear()
 attacking = false
 phase_seen = "combat"
 live_hud.close_panels()
 _present()

func _rescue() -> void:
 if simulation.self_rescue():
  ledger.command("life_state",{"dead":false})
  live_hud.close_panels()
  _present()

func _modal_boundary(blocked: bool) -> void:
 # Returning to a safe room focuses its primary action; Tab can still select any HUD button.
 if not blocked and simulation.phase in ["preparation","victory"]:
  _present()
  start_button.grab_focus()

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
  var code: int = event.keycode
  if enter_start_keys.has(code):
   if not event.pressed: enter_start_keys.erase(code)
   get_viewport().set_input_as_handled()
   return
  var focused: Control = get_viewport().gui_get_focus_owner()
  if event.pressed and not event.echo and not live_hud.shade.visible and simulation.phase in ["preparation","victory"] and (focused == null or focused == start_button):
   enter_start_keys[code] = true
   start_room()
   get_viewport().set_input_as_handled()
   return
 # Own the complete rescue key cycle before a focused Button can consume ui_accept.
 if event is InputEventKey and event.keycode == KEY_SPACE:
  if not event.pressed and rescue_space_latched:
   rescue_space_latched = false
   get_viewport().set_input_as_handled()
   return
  if event.pressed and not event.echo and simulation.phase == "downed" and not live_hud.shade.visible:
   rescue_space_latched = true
   _rescue()
   get_viewport().set_input_as_handled()
   return
 # Releases must clear the latch even when a Control consumes the event later.
 if event is InputEventKey and not event.pressed:
  held_keys.erase(event.physical_keycode if event.physical_keycode else event.keycode)
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
  attacking = false
 if event is InputEventMouseMotion: mouse_at = event.position

func _unhandled_input(event: InputEvent) -> void:
 if is_instance_valid(live_hud) and live_hud.shade.visible: return
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode else event.keycode
  if not event.pressed or event.echo: return
  if key in [KEY_ENTER,KEY_KP_ENTER]: return # GUI-owned activation never falls through into the shortcut.
  elif key == KEY_F5: new_run()
  elif key == KEY_SPACE and simulation.phase == "downed":
   _rescue()
  else:
   if simulation.phase == "combat": held_keys[key] = true
   var action: String = {KEY_Q:"q",KEY_E:"e",KEY_R:"r",KEY_SHIFT:"shift"}.get(key,"")
   if not action.is_empty(): _perform_action(action)
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and simulation.phase == "combat" and not live_hud.blocks_gameplay_input():
  mouse_at = event.position
  attacking = true
  _perform_action("attack")

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  enter_start_keys.clear()
  rescue_space_latched = false
  held_keys.clear()
  attacking = false

func _physics_process(dt: float) -> void:
 if not is_instance_valid(simulation) or not is_instance_valid(live_hud): return
 if live_hud.shade.visible:
  held_keys.clear()
 if live_hud.blocks_gameplay_input():
  attacking = false
 if simulation.phase == "combat":
  simulation.hero.move_intent = Vector3(float(held_keys.get(KEY_D,false))-float(held_keys.get(KEY_A,false)),0,float(held_keys.get(KEY_S,false))-float(held_keys.get(KEY_W,false))).limit_length(1)
  var aim: Vector3 = _aim_point()
  if not simulation.r1_active and simulation.hero.lock_time <= 0:
   var direction: Vector3 = aim - simulation.hero.position
   if direction.length_squared() > 0.01: simulation.hero.facing = direction.normalized()
  if attacking: _perform_action("attack","",false)
  simulation.step(dt)
 _sync_views(dt)
 _animate(dt)
 _step_effects(dt)
 _present()
 _sync_growth_to_combat()

func _request(request: Dictionary) -> void:
 # UI callbacks never reenter a combat transaction.
 call_deferred("_execute_ui_request",request.duplicate(true))

func _execute_ui_request(request: Dictionary) -> void:
 var result := {"accepted":false,"reason":"stage_not_available"}
 if request.action == "ability":
  result = _perform_action(str(request.slot_id).to_lower(),request.command_id,false)
 elif request.action == "use_item":
  result = consumers.use_recovery(simulation,ledger.model,request.command_id,int(request.get("uid",-1)))
 _present()
 controller.complete_combat_request(request,result)

func _perform_action(action: String, command_id := "", notify := true) -> Dictionary:
 action_serial += 1
 var id: String = command_id
 if id.is_empty() and notify: id = "%s/input-%d" % [run_id,action_serial]
 var result: Dictionary = simulation.request_action(action,_aim_point(),id)
 # Held attack polls do not allocate an idempotency record every physics frame.
 if notify or result.accepted or not id.is_empty():
  last_action_receipt = {"action":action,"result":result.duplicate(true),"command_id":id}
 if notify and not result.accepted and is_instance_valid(controller):
  live_hud.adapter.feedback({"text":controller.reason_text(result.reason)})
 return result

func _growth_completed(_request: Dictionary, result: Dictionary) -> void:
 if result.accepted:
  _sync_growth_to_combat()
  _present()

func _sync_growth_to_combat() -> void:
 simulation._sync_loadout_from_ledger()
 # Recompute from immutable base, never stack on the previous projection or refill HP/CD.
 consumers.sync_stats(simulation,ledger.model)
 simulation.hero.xp_progress = ledger.model.snapshot().xp
 simulation.hero.gold = ledger.model.snapshot().gold

func _credit_kill(event: Dictionary) -> Dictionary:
 if event.get("combat_level_id","") != simulation.combat_level_id: return {"accepted":false,"reason":"wrong_room"}
 var enemy: Dictionary = simulation.enemy_by_id(event.get("target",""))
 if enemy.is_empty() or not enemy.dead: return {"accepted":false,"reason":"not_dead"}
 var id: String = "%s/%s" % [simulation.combat_level_id,enemy.actor_id]
 return ledger.model.command("reward:"+id,"reward_minion",{"event_id":id,"room":simulation.combat_level_id,"gold":REWARD.gold,"xp":REWARD.xp})

func _room_rewards() -> Dictionary:
 var total := {"gold":0,"xp":0}
 for reward in ledger.model.snapshot().get("credited_rewards",{}).values():
  if reward.room == simulation.combat_level_id:
   total.gold += reward.gold
   total.xp += reward.xp
 return total

func _encounter_finished(state: Dictionary) -> void:
 var identity: String = "%s/%s/%s" % [state.combat_level_id,state.phase,state.event_sequence]
 if terminal_seen.has(identity): return
 terminal_seen[identity] = true
 attacking = false
 held_keys.clear()
 if state.phase in ["downed","true_dead"]:
  ledger.command("life_state",{"dead":true})
  ledger.command("context",{"phase":"combat"})
 if state.phase == "true_dead":
  ledger.model.command("death:"+identity,"death_penalty",{"event_id":identity})
 _sync_growth_to_combat()
 var earnings := _room_rewards()
 # Defer UI work until the lethal combat transaction has committed.
 call_deferred("_show_settlement",state.phase,earnings)

func _show_settlement(phase: String, earnings: Dictionary) -> void:
 _present()
 live_hud.show_result({"title":{"victory":"房间完成 · 关闭后可购物或进入下一房","downed":"倒地 · 关闭后空格自救一次","true_dead":"真死亡 · 已扣本级经验30%"}.get(phase,phase),"kills":_kills(),"gold":earnings.gold,"xp":earnings.xp,"source_label":"奖励已按唯一击杀入账，不在结算时重发。F5仅真死亡后续战，保留账本/CD。"})

func _kills() -> int:
 var n := 0
 for enemy in simulation.enemies:
  if enemy.dead: n += 1
 return n

func _action_status(action: String) -> String:
 var h = simulation.hero
 if simulation.phase != "combat": return "准备中" if simulation.phase == "preparation" else "战后冻结"
 if h.dead: return "无法行动"
 if action == "passive": return "被动生效"
 if action == "e" and h.overload_left > 0: return "持续中 %.1fs" % h.overload_left
 if action == "q" and h.cast_state.has("q2"): return "突袭持续中"
 if action == "e" and h.cast_state.has("e2"): return "旋斩持续中"
 if h.lock_time > 0 or h.dash_left > 0 or h.stun_left > 0 or simulation.r1_active or simulation.extensions.blocks_actions(): return "动作锁定"
 if action == "e" and h.cast_state.has("e1"): return "可重施" if h.cast_state.e1.stage == "marked" else "匕首飞行中"
 if action == "r" and h.cast_state.has("r2"): return "可重施 · 第%d投" % (h.cast_state.r2.round+1)
 return "就绪"

func _present() -> void:
 if not is_instance_valid(controller): return
 var h: Dictionary = simulation.hero.snapshot()
 var skills := {}
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"],["Shift","shift"]]:
  skills[pair[0]] = {"cooldown":h.cooldowns[pair[1]],"reason":_action_status(pair[1])}
 controller.present_combat({"hp":h.hp,"hp_max":h.max_hp,"room":"第%d房 · %d/%d" % [room_number,_kills(),simulation.enemies.size()],"wave":"%d" % (1+(maxi(1,room_number)-1)%2),"skills":skills})
 start_button.text = "进入第%d房" % (room_number+1)
 start_button.visible = simulation.phase in ["preparation","victory"] and not live_hud.shade.visible
 help_text.visible = simulation.phase in ["preparation","victory"] and not live_hud.shade.visible
 if not live_hud.shade.visible:
  var controls: Array[Control] = [live_hud.allocation,live_hud.supply_button]
  if start_button.visible: controls.push_front(start_button)
  for button in live_hud.slots.values(): controls.append(button)
  for button in live_hud.equipment: controls.append(button)
  live_hud._cycle_focus(controls)
  var focused: Control = get_viewport().gui_get_focus_owner()
  if focused == null or not focused.is_visible_in_tree():
   if start_button.visible: start_button.grab_focus()
   else: live_hud.allocation.grab_focus()

func _on_combat_event(event: Dictionary) -> void:
 super._on_combat_event(event)
 if event.kind == "kill":
  var receipt: Dictionary = _credit_kill(event)
  if not receipt.accepted: reward_errors.append(receipt)
 var clip: String = {"attack_started":"attack","dash":"dash","q1":"thrust","q2_hit":"thrust","q3_wave":"attack","overload_started":"overload","ultimate_started":"ultimate","hero_damaged":"hit"}.get(event.kind,"")
 if not clip.is_empty():
  hero_clip = {"clip":clip,"start":simulation.clock.world_time,"duration":{"attack_started":0.28,"dash":0.16,"q1":0.2,"hero_damaged":0.25}.get(event.kind,0.6)}

func _animate(dt: float) -> void:
 var s: Dictionary = simulation.snapshot()
 var actors: Array = s.enemies.duplicate()
 var hero: Dictionary = s.hero.duplicate()
 hero["kind"] = "hero"
 actors.append(hero)
 for actor in actors:
  var id: String = actor.actor_id
  if not views.has(id): continue
  var player: AnimationPlayer = views[id].animation_player
  if player == null: continue
  player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var m: Dictionary = motion.get(id,{"position":actor.position,"walk":0.0,"death":-1.0,"clip":"idle","time":0.0})
  var offset: Vector3 = actor.position - m.position
  var distance: float = offset.length()
  m.position = actor.position
  var clip := "idle"
  var t: float = s.world_time
  if actor.dead:
   if m.death < 0: m.death = s.world_time
   clip = "death"
   # Death is presentation only, allowed to finish after logical freeze.
   m.time += dt
   t = m.time if m.clip == "death" else 0.0
  elif actor.kind != "hero" and actor.state == "warning":
   clip = "windup"
   t = T.INITIAL[actor.kind+"_warning"] - actor.timer
  elif actor.kind != "hero" and actor.state == "recover":
   clip = "release"
   t = (1.6 if actor.kind == "boss" else 1.1) - actor.timer
  elif actor.kind == "hero" and not hero_clip.is_empty() and s.world_time-hero_clip.start < hero_clip.duration:
   clip = hero_clip.clip
   t = (s.world_time-hero_clip.start)/hero_clip.duration*player.get_animation(clip).length
  elif distance > 0.00001:
   clip = "run" if actor.kind == "hero" else "walk"
   m.walk += distance / (2.0 if actor.kind == "hero" else 1.15)
   t = m.walk
   if actor.kind != "hero": views[id].rotation.y = atan2(-offset.x,-offset.z)
  if s.phase not in ["combat","preparation"] and not actor.dead:
   clip = m.clip
   t = m.time
  if player.has_animation(clip):
   var length: float = player.get_animation(clip).length
   if clip in ["idle","run","walk"]: t = fposmod(t,length)
   else: t = clampf(t,0,length)
   player.play(clip)
   player.seek(t,true)
  m.clip = clip
  m.time = t
  motion[id] = m

func integration_snapshot() -> Dictionary:
 return {"combat":simulation.snapshot(),"growth":ledger.model.snapshot(),"hud":live_hud.adapter.state,"kills":_kills(),"panel_open":live_hud.shade.visible,"attacking":attacking,"animations":motion.duplicate(true),"checkpoint":"3_recovery_stats","room_number":room_number,"reward_errors":reward_errors.duplicate(),"last_action_receipt":last_action_receipt.duplicate(true)}

func integration_report() -> String:
 return JSON.stringify(integration_snapshot())
