extends "res://scripts/combat/arena.gd"
## First playable checkpoint. Combat tuning is experimental; rewards remain unresolved.
const Bridge = preload("res://scripts/integration/ledger_bridge.gd")
const CombatHUD = preload("res://scripts/ui/combat_hud.gd")
var ledger: RefCounted
var live_hud: Control
var start_button: Button
var help_text: Label
var attacking := false
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
 live_hud.adapter.request_emitted.connect(_request)
 start_button = Button.new()
 start_button.text = "进入试炼 [Enter]"
 start_button.position = Vector2(510,24)
 start_button.size = Vector2(240,42)
 live_hud.add_child(start_button)
 start_button.pressed.connect(start_room)
 help_text = Label.new()
 help_text.text = "WASD 移动 · 左键攻击 · Q/E/R 技能 · Shift 冲刺 · K 修习\n战前选 1 点技能；战斗参数为测试初值，奖励尚未接入"
 help_text.position = Vector2(350,78)
 help_text.add_theme_font_size_override("font_size",14)
 live_hud.add_child(help_text)
 _present()
 print("SHUABAO_INTEGRATION_READY checkpoint=1")

func new_run() -> void:
 if is_instance_valid(simulation):
  remove_child(simulation)
  simulation.queue_free()
 for view in views.values(): view.queue_free()
 views.clear()
 for effect in effects: effect.node.queue_free()
 effects.clear()
 held_keys.clear()
 attacking = false
 motion.clear()
 hero_clip.clear()
 run_serial += 1
 ledger = Bridge.new()
 simulation = Sim.new()
 simulation.progression = ledger
 simulation.hero.xp_progress = 0.0
 simulation._sync_loadout_from_ledger()
 simulation.phase = "preparation"
 simulation.name = "CombatSimulation"
 add_child(simulation)
 simulation.combat_event.connect(_on_combat_event)
 phase_seen = "preparation"
 _sync_views(0)
 if is_instance_valid(live_hud):
  live_hud.close_panels()
  _present()

func start_room() -> void:
 if simulation.phase != "preparation": return
 ledger.command("enter_level",{"combat_level_id":"integration-room-1"})
 ledger.begin_encounter()
 simulation.phase = "combat"
 simulation.combat_level_id = "integration-room-1"
 for pos in T.TEST_MINION_POSITIONS: simulation.spawn_enemy("minion",pos)
 simulation.spawn_enemy("elite",Vector3(-5,0,-7))
 simulation.spawn_enemy("elite",Vector3(5,0,-8))
 simulation.spawn_enemy("boss",Vector3(0,0,-10))
 held_keys.clear()
 attacking = false
 _present()

func _input(event: InputEvent) -> void:
 # Releases must clear the latch even when a Control consumes the event later.
 if event is InputEventKey and not event.pressed:
  held_keys.erase(event.physical_keycode if event.physical_keycode else event.keycode)
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
  attacking = false
 if event is InputEventMouseMotion: mouse_at = event.position

func _unhandled_input(event: InputEvent) -> void:
 if is_instance_valid(live_hud) and live_hud.blocks_gameplay_input(): return
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode else event.keycode
  if not event.pressed or event.echo: return
  if key == KEY_ENTER: start_room()
  elif key == KEY_F5: new_run()
  elif key == KEY_SPACE and simulation.phase == "downed":
   if simulation.self_rescue(): live_hud.close_panels()
  elif simulation.phase == "combat":
   held_keys[key] = true
   var action: String = {KEY_Q:"q",KEY_E:"e",KEY_R:"r",KEY_SHIFT:"shift"}.get(key,"")
   if not action.is_empty(): simulation.request_action(action,_aim_point())
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and simulation.phase == "combat":
  mouse_at = event.position
  attacking = true
  simulation.request_action("attack",_aim_point())

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  held_keys.clear()
  attacking = false

func _physics_process(dt: float) -> void:
 if not is_instance_valid(simulation) or not is_instance_valid(live_hud): return
 if live_hud.blocks_gameplay_input():
  held_keys.clear()
  attacking = false
 if simulation.phase == "combat":
  simulation.hero.move_intent = Vector3(float(held_keys.get(KEY_D,false))-float(held_keys.get(KEY_A,false)),0,float(held_keys.get(KEY_S,false))-float(held_keys.get(KEY_W,false))).limit_length(1)
  var aim: Vector3 = _aim_point()
  if not simulation.r1_active and simulation.hero.lock_time <= 0:
   var direction: Vector3 = aim - simulation.hero.position
   if direction.length_squared() > 0.01: simulation.hero.facing = direction.normalized()
  if attacking: simulation.request_action("attack",aim)
  simulation.step(dt)
 _sync_views(dt)
 _animate(dt)
 _step_effects(dt)
 _present()
 if phase_seen != simulation.phase:
  phase_seen = simulation.phase
  if phase_seen in ["victory","downed","true_dead"]:
   attacking = false
   held_keys.clear()
   live_hud.show_result({"title":{"victory":"试炼完成","downed":"倒地 · 关闭后按空格自救一次","true_dead":"本次试炼结束"}[phase_seen],"kills":_kills(),"gold":0,"xp":0,"source_label":"HP/CD 已冻结 · 奖励待接入 · 关闭后 F5 新开一局"})

func _request(request: Dictionary) -> void:
 if request.action == "ability":
  var action: String = str(request.slot_id).to_lower()
  simulation.request_action(action,_aim_point(),request.command_id)
  return
 if request.action != "learn":
  live_hud.adapter.feedback({"text":"本 checkpoint 尚未接入此操作"})
  return
 if simulation.phase not in ["preparation","combat"]:
  live_hud.adapter.feedback({"text":"战斗已结束，状态保持冻结"})
  return
 var result: Dictionary = ledger.model.command(request.command_id,"learn",{"slot":request.slot_id,"candidate":request.candidate_id,"expected_rank":request.expected_rank})
 if result.accepted: simulation._sync_loadout_from_ledger()
 live_hud.adapter.feedback({"text":"修习成功" if result.accepted else "无法修习："+str(result.reason)})
 _present()

func _kills() -> int:
 var n := 0
 for enemy in simulation.enemies:
  if enemy.dead: n += 1
 return n

func _present() -> void:
 if not is_instance_valid(live_hud): return
 var s: Dictionary = ledger.model.snapshot()
 var h: Dictionary = simulation.hero.snapshot()
 var skills := {}
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  var skill: Dictionary = s.skills[pair[0]]
  var index: int = maxi(0,int(str(skill.candidate).right(1))-1)
  skills[pair[0]] = {"name":CombatHUD.CANDIDATES[pair[0]][index] if skill.rank else "未学习","candidate_index":index,"rank":skill.rank,"cooldown":h.cooldowns[pair[1]],"reason":"就绪" if skill.rank else "未学习"}
 skills.Shift = {"name":"冲刺","rank":1,"cooldown":h.cooldowns.shift}
 live_hud.adapter.present({"actor_id":"fengli","revision":s.revision,"level":s.level,"points":s.points,"hp":h.hp,"hp_max":h.max_hp,"xp":s.xp,"xp_next":0,"gold":s.gold,"room":"击败 %d / 11" % _kills(),"wave":"1","source_label":"真实战斗状态 · 奖励未接入","skills":skills,"equipment":[],"can_undo":false})
 start_button.visible = simulation.phase == "preparation" and not live_hud.shade.visible
 help_text.visible = simulation.phase == "preparation" and not live_hud.shade.visible

func _on_combat_event(event: Dictionary) -> void:
 super._on_combat_event(event)
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
 return {"combat":simulation.snapshot(),"growth":ledger.model.snapshot(),"hud":live_hud.adapter.state,"kills":_kills(),"panel_open":live_hud.shade.visible,"attacking":attacking,"animations":motion.duplicate(true),"checkpoint":"1_rewards_unresolved"}

func integration_report() -> String:
 return JSON.stringify(integration_snapshot())
