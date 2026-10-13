extends Node3D
## Local single-room Xuanlei arena. Explicit prototype values; formal and test ledgers isolated.
const Sim = preload("res://scripts/combat/xuanlei_sim.gd")
const Bridge = preload("res://scripts/integration/ledger_bridge.gd")
const HUD = preload("res://scripts/ui/progression_hud.gd")
const Controller = preload("res://scripts/ui/progression_controller.gd")
const Stage = preload("res://scripts/integration/xuanlei_environment.gd")
const ActorView = preload("res://scripts/integration/xuanlei_actor_view.gd")
const ActTrial = preload("res://scripts/integration/act_trial.gd")
const EnemyActorView = preload("res://scripts/integration/enemy_actor_view.gd")
const Consumers = preload("res://scripts/integration/consumers.gd")
var simulation: Node
var ledger: RefCounted
var controller: RefCounted
var consumers = Consumers.new()
var live_hud: Control
var environment: Node3D
var camera: Camera3D
var views := {}
var effects: Array = []
var held_keys := {}
var mouse_at := Vector2(640,300)
var attacking := false
var start_button: Button
var help_text: Label
var mute_button: Button
var density_select: OptionButton
var auto_waves: CheckButton
var training_button: Button
var range_guides: CheckButton
var health_values: CheckButton
var training_open := false
var pressure_count := -1
var intermission_left := 8.0
var audio_router: Node
var room_number := 1
var wave_number := 0
var run_id := ""
var action_serial := 0
var last_action_receipt := {}
var reward_errors: Array = []
var terminal_seen := {}
var saved_formal := {}
var test_mode := false
var enter_latched := false
var manual_step := false
var telemetry_elapsed := 0.0
var input_trace: Array = []
var visual_assets := {}
var enemy_combat_vfx: Node3D
var common_hex_vfx: Node3D
var siege_vfx: Node3D
var attack_vfx:Node3D
var state_vfx: Node3D
var projectile_view: MultiMeshInstance3D
var contact_shadows: MultiMeshInstance3D
var growth_revision := -1
var growth_model_id := 0
var hud_elapsed := 0.0
var hud_phase := ""
var hud_revision := -1
var action_buffer := {}
var hitstop_left := 0.0
var camera_kick := 0.0
var hurt_tint: ColorRect
var attack_status: Label
var last_hitstop_cast := -1
var dash_feedback_left := 0.0
var attack_result := ""
var attack_result_left := 0.0
var dash_trail_tick := 0.0
var was_dashing := false
var act_trial=ActTrial.new()
var mode_select:OptionButton
var free_room_suffix:="/room-1"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_diagnostics_root())
	environment=Stage.new()
	add_child(environment)
	camera=environment.camera
	audio_router=preload("res://scripts/audio/xuanlei_router.gd").new()
	add_child(audio_router)
	siege_vfx=preload("res://assets/xuanlei/vfx/siege_vfx.tscn").instantiate()
	add_child(siege_vfx)
	attack_vfx=preload("res://assets/xuanlei/vfx/basic_attacks.gd").new()
	add_child(attack_vfx);attack_vfx.set_process(false)
	enemy_combat_vfx=preload("res://assets/enemies/siege_brood/vfx/enemy_combat_vfx.gd").new()
	add_child(enemy_combat_vfx)
	common_hex_vfx=preload("res://scripts/integration/common_hex_vfx.gd").new()
	add_child(common_hex_vfx)
	projectile_view=MultiMeshInstance3D.new()
	projectile_view.multimesh=MultiMesh.new()
	projectile_view.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var bolt:=SphereMesh.new()
	bolt.radius=0.16;bolt.height=0.32;bolt.radial_segments=8;bolt.rings=4
	projectile_view.multimesh.mesh=bolt
	projectile_view.multimesh.instance_count=256
	projectile_view.multimesh.visible_instance_count=0
	projectile_view.material_override=Stage.material(Color("ffa86b"),0.5,0,1.3)
	add_child(projectile_view)
	contact_shadows=MultiMeshInstance3D.new()
	contact_shadows.multimesh=MultiMesh.new()
	contact_shadows.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var shadow_disc:=CylinderMesh.new()
	shadow_disc.top_radius=0.55;shadow_disc.bottom_radius=0.55;shadow_disc.height=0.003;shadow_disc.radial_segments=12
	contact_shadows.multimesh.mesh=shadow_disc
	contact_shadows.multimesh.instance_count=181
	contact_shadows.multimesh.visible_instance_count=0
	var shadow_mat:=Stage.material(Color(0.035,0.06,0.07,0.28))
	shadow_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	contact_shadows.material_override=shadow_mat
	contact_shadows.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(contact_shadows)
	_load_visuals()
	ledger=Bridge.new("xuanlei")
	run_id="xuanlei-%d" % Time.get_ticks_usec()
	ledger.command("enter_level",{"combat_level_id":run_id+free_room_suffix})
	simulation=_new_sim(ledger)
	var layer:=CanvasLayer.new()
	layer.name="IntegratedHUD"
	add_child(layer)
	live_hud=HUD.new()
	layer.add_child(live_hud)
	controller=Controller.new()
	controller.combat_request.connect(_request)
	controller.command_completed.connect(_growth_completed)
	controller.test_loadout_requested.connect(_request_test_loadout)
	_bind_controller()
	start_button=Button.new()
	start_button.position=Vector2(490,20)
	start_button.size=Vector2(300,44)
	start_button.pressed.connect(start_room)
	live_hud.add_child(start_button)
	mode_select=OptionButton.new()
	mode_select.position=Vector2(28,22);mode_select.size=Vector2(330,38)
	mode_select.add_item("自由竞技场 · 波次不计大层")
	mode_select.add_item("断门关 · 一幕机制试炼")
	mode_select.tooltip_text="一幕试炼包含外城、斜堡、城心首领三个固定战斗房；完整通关且Boss确已击败才结算大层。此路径不是完整战役。"
	mode_select.item_selected.connect(func(index:int):
		if simulation.phase!="preparation" or wave_number>0:return
		act_trial.active=index==1
		act_trial.save_to(ledger.model)
		_present())
	live_hud.add_child(mode_select)
	help_text=Label.new()
	help_text.position=Vector2(350,78)
	help_text.add_theme_font_size_override("font_size",14)
	live_hud.add_child(help_text)
	mute_button=Button.new()
	mute_button.position=Vector2(1120,116)
	mute_button.size=Vector2(130,36)
	mute_button.text="音效：开"
	mute_button.pressed.connect(_toggle_audio)
	live_hud.add_child(mute_button)
	density_select=OptionButton.new()
	density_select.position=Vector2(800,128)
	density_select.size=Vector2(250,38)
	for count in [-1,8,18,36,72,180]:
		density_select.add_item("敌量：随成长" if count<0 else "压力测试：%d敌" % count)
		density_select.set_item_metadata(density_select.item_count-1,count)
	density_select.item_selected.connect(func(index: int): pressure_count=int(density_select.get_item_metadata(index)))
	live_hud.add_child(density_select)
	auto_waves=CheckButton.new()
	auto_waves.position=Vector2(490,128)
	auto_waves.size=Vector2(290,38)
	auto_waves.text="自动续波 · 间歇8秒"
	live_hud.add_child(auto_waves)
	training_button=Button.new()
	training_button.position=Vector2(840,78)
	training_button.size=Vector2(180,34)
	training_button.text="训练设置 ▾"
	training_button.pressed.connect(func(): training_open=not training_open;_present())
	live_hud.add_child(training_button)
	range_guides=CheckButton.new()
	range_guides.position=Vector2(490,170)
	range_guides.size=Vector2(260,34)
	range_guides.text="距离参照线（仅自由测试）"
	range_guides.toggled.connect(func(enabled: bool): environment.set_distance_guides(enabled and test_mode))
	live_hud.add_child(range_guides)
	health_values=CheckButton.new()
	health_values.position=Vector2(800,170)
	health_values.size=Vector2(250,34)
	health_values.text="详细敌人生命（仅测试）"
	live_hud.add_child(health_values)
	attack_status=Label.new()
	attack_status.mouse_filter=Control.MOUSE_FILTER_PASS
	attack_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	attack_status.position=Vector2(-285,-247)
	attack_status.size=Vector2(570,25)
	attack_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	attack_status.add_theme_font_size_override("font_size",14)
	live_hud.add_child(attack_status)
	hurt_tint=ColorRect.new()
	hurt_tint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hurt_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_tint.color=Color(0.7,0.08,0.035,0)
	live_hud.add_child(hurt_tint)
	_sync_growth_to_combat()
	_present()
	_sync_views(0)
	print("SHUABAO_INTEGRATION_READY checkpoint=xuanlei-local")

func _load_visuals() -> void:
	for kind in ["hero","minion","pouncer","ranged","armored","pitcher","support","elite","boss"]:
		var path: String="res://assets/xuanlei/xuanlei.glb" if kind=="hero" else "res://assets/enemies/siege_brood/"+kind+"/"+kind+".glb"
		if ResourceLoader.exists(path): visual_assets[kind]=load(path)
		elif kind!="hero" and ResourceLoader.exists("res://assets/arena/enemies/"+kind+".glb"): visual_assets[kind]=load("res://assets/arena/enemies/"+kind+".glb")

func _new_sim(authority: RefCounted) -> Node:
	if is_instance_valid(common_hex_vfx):common_hex_vfx.reset()
	if is_instance_valid(attack_vfx):attack_vfx.clear_transients()
	var next=Sim.new()
	next.name="CombatSimulation"
	next.progression=authority
	add_child(next)
	next.combat_event.connect(_on_combat_event)
	next.encounter_finished.connect(_encounter_finished)
	return next

func _bind_controller() -> void:
	controller.bind(ledger.model,live_hud,ledger.definitions,{"hex_enabled":true,"source_label":"玄垒 · 最终机制整合","content_label":"3Q / 3E / 3被动 / 2R · 16专属Hex · 最终机制v0.3"})

func _toggle_audio() -> void:
	audio_router.sfx.set_muted(not audio_router.sfx.muted)
	mute_button.text="音效：关" if audio_router.sfx.muted else "音效：开"

func start_room() -> void:
	if simulation.phase=="true_dead":
		retry_room();return
	if simulation.phase not in ["preparation","victory"] or controller.auto_hex_pending() or live_hud.shade.visible:return
	if act_trial.active and act_trial.completed:
		act_trial.active=false;act_trial.save_to(ledger.model)
		free_room_suffix="/post-trial-free"
		mode_select.select(0)
		_present();return
	var next_room:String=act_trial.room_id(run_id) if act_trial.active else run_id+free_room_suffix
	if ledger.model.state.combat_level_id!=next_room:
		var entered:Dictionary=ledger.command("enter_level",{"combat_level_id":next_room})
		if not entered.ok:return
	intermission_left=8.0
	wave_number+=1
	var roster:Array=act_trial.roster() if act_trial.active else simulation.make_wave_roster(wave_number,pressure_count if test_mode else -1)
	if simulation.has_method("set_common_context"):
		simulation.set_common_context({"run_id":run_id,"encounter_kind":act_trial.room_data().kind if act_trial.active else "ordinary"})
	var result:Dictionary=simulation.begin_encounter(next_room,roster)
	if not result.accepted:wave_number-=1;return
	if act_trial.active:
		ledger.model.config.campaign_acts={ActTrial.ACT_ID:ActTrial.DEFINITION.duplicate(true)}
		var registered:Dictionary=act_trial.register_current_boss(simulation,ledger.model,run_id)
		if not registered.accepted:reward_errors.append({"source":"act_trial","reason":registered.reason})
		act_trial.save_to(ledger.model)
	held_keys.clear();attacking=false;action_buffer.clear();_present()

func retry_room() -> void:
	if simulation.phase!="true_dead": return
	ledger.command("life_state",{"dead":false})
	ledger.begin_encounter()
	simulation.hero.dead=false
	simulation.hero.death_state="alive"
	simulation.hero.hp=simulation.hero.stats.max_hp*0.35
	simulation.hero.position=Vector3.ZERO
	simulation.phase="combat"
	simulation.paused=false
	held_keys.clear()
	attacking=false
	action_buffer.clear()

func _request_test_loadout(spec: Dictionary) -> void:
	call_deferred("_complete_test_loadout",spec.duplicate(true))

func _complete_test_loadout(spec: Dictionary) -> void:
	var result: Dictionary = _enter_test_loadout(spec)
	controller.complete_test_loadout_request(result)

func _enter_test_loadout(spec: Dictionary) -> Dictionary:
	if simulation.phase not in ["preparation","victory"]: return {"accepted":false,"reason":"unsafe_phase"}
	if spec.get("return_normal",false):
		if saved_formal.is_empty(): return {"accepted":false,"reason":"no_formal_run"}
		simulation.queue_free()
		simulation=saved_formal.simulation
		ledger=saved_formal.ledger
		consumers=saved_formal.consumers
		wave_number=saved_formal.wave
		run_id=saved_formal.run_id
		act_trial=saved_formal.get("act_trial",ActTrial.new())
		free_room_suffix=saved_formal.get("free_room_suffix","/room-1")
		auto_waves.set_pressed_no_signal(bool(saved_formal.get("auto_waves",false)))
		intermission_left=float(saved_formal.get("intermission_left",8.0))
		saved_formal.clear()
		test_mode=false
		range_guides.button_pressed=false
		health_values.button_pressed=false
		environment.set_distance_guides(false)
		pressure_count=-1
		density_select.select(0)
	else:
		var candidate=Bridge.new("xuanlei")
		var result: Dictionary=candidate.configure_test(spec)
		if not result.accepted:
			live_hud.adapter.feedback({"text":controller.reason_text(result.reason)})
			return result
		if saved_formal.is_empty():
			saved_formal={"simulation":simulation,"ledger":ledger,"consumers":consumers,"wave":wave_number,"run_id":run_id,"auto_waves":auto_waves.button_pressed,"intermission_left":intermission_left,"act_trial":act_trial,"free_room_suffix":free_room_suffix}
		else: simulation.queue_free()
		ledger=candidate
		consumers=Consumers.new()
		simulation=_new_sim(ledger)
		wave_number=0
		run_id="sandbox-%d" % Time.get_ticks_usec()
		test_mode=true
		act_trial=ActTrial.new();free_room_suffix="/room-1"
		ledger.command("enter_level",{"combat_level_id":run_id+free_room_suffix})
	for view in views.values(): view.queue_free()
	views.clear()
	for effect in effects: effect.node.queue_free()
	effects.clear()
	held_keys.clear()
	attacking=false
	action_buffer.clear()
	live_hud.set_hex_required(false)
	live_hud.close_panels()
	_bind_controller()
	_sync_growth_to_combat()
	_present()
	return {"accepted":true,"reason":"ok"}

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and input_trace.size()<32: input_trace.append(event.as_text())
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		DirAccess.make_dir_recursive_absolute(_diagnostics_root()+"/screenshots")
		get_viewport().get_texture().get_image().save_png(_diagnostics_root()+"/screenshots/xuanlei-%d.png" % Time.get_ticks_msec())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion: mouse_at=event.position
	if event is InputEventKey:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if not event.pressed:
			held_keys.erase(key)
			if key==KEY_E and not simulation.paused:
				if action_buffer.get("action","")=="e":action_buffer["released"]=true
				simulation.request_action("e_release",_aim_point())
		if key in [KEY_ENTER,KEY_KP_ENTER] and enter_latched:
			if not event.pressed: enter_latched=false
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo and key in [KEY_ENTER,KEY_KP_ENTER] and not live_hud.shade.visible and simulation.phase in ["preparation","victory"]:
			var focused: Control=get_viewport().gui_get_focus_owner()
			if focused==null or focused==start_button:
				enter_latched=true
				start_room()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: attacking=false

func _unhandled_input(event: InputEvent) -> void:
	if live_hud.shade.visible: return
	if event is InputEventKey:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if not event.pressed or event.echo: return
		if key==KEY_F5 and simulation.phase=="true_dead": retry_room()
		if key>=KEY_1 and key<=KEY_6 and simulation.phase in ["preparation","combat","victory"]:
			var index:int=key-KEY_1
			var inventory:Array=ledger.model.state.inventory
			live_hud.adapter.request("item",{"slot_index":index,"uid":inventory[index].uid if index<inventory.size() else -1})
			get_viewport().set_input_as_handled()
			return
		if key in [KEY_W,KEY_A,KEY_S,KEY_D]: held_keys[key]=true
		var action: String={KEY_Q:"q",KEY_E:"e",KEY_R:"r",KEY_SHIFT:"shift"}.get(key,"")
		if not action.is_empty(): _perform_action(action)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and simulation.phase=="combat":
		mouse_at=event.position
		attacking=true
		_perform_action("attack")

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		held_keys.clear()
		attacking=false
		action_buffer.clear()
		enter_latched=false

func _aim_point() -> Vector3:
	var result=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse_at),camera.project_ray_normal(mouse_at))
	return result if result!=null else simulation.hero.position+simulation.hero.facing

func _physics_process(dt: float) -> void:
	if not is_instance_valid(simulation) or not is_instance_valid(live_hud): return
	telemetry_elapsed+=dt
	if telemetry_elapsed>=3.0:
		telemetry_elapsed=0
		var telemetry=FileAccess.open(_diagnostics_root()+"/live-telemetry.json",FileAccess.WRITE)
		if telemetry: telemetry.store_string(JSON.stringify({"fps":Engine.get_frames_per_second(),"frame":Engine.get_process_frames(),"phase":simulation.phase,"paused":simulation.paused,"inputs":input_trace,"hud":live_hud.shade.visible,"wave":wave_number}))
	if growth_revision!=int(ledger.model.state.revision) or growth_model_id!=ledger.model.get_instance_id(): _sync_growth_to_combat()
	simulation.paused=controller.auto_hex_pending() or live_hud.shade.visible
	audio_router.set_paused(simulation.paused)
	if controller.auto_hex_pending(): controller.ensure_auto_hex()
	if simulation.paused:
		held_keys.clear()
		attacking=false
		action_buffer.clear()
	var world_before: float=simulation.clock.world_time
	var stopping: bool=hitstop_left>0
	hitstop_left=maxf(0,hitstop_left-dt)
	camera_kick=maxf(0,camera_kick-dt)
	dash_feedback_left=maxf(0,dash_feedback_left-dt)
	attack_result_left=maxf(0,attack_result_left-dt)
	hurt_tint.color.a=maxf(0,hurt_tint.color.a-dt*0.75)
	var move:=Vector3(float(held_keys.get(KEY_D,false))-float(held_keys.get(KEY_A,false)),0,float(held_keys.get(KEY_S,false))-float(held_keys.get(KEY_W,false))).limit_length(1)
	if not manual_step and not simulation.paused and simulation.phase=="combat":
		simulation.hero.move_intent=move
		if stopping: simulation.move_during_hitstop(dt,move)
	if not manual_step and not simulation.paused and not stopping:
		if simulation.phase=="combat":
			simulation.hero.move_intent=move
			var direction: Vector3=_aim_point()-simulation.hero.position
			if direction.length_squared()>0.01 and simulation.hero.lock_time<=0: simulation.hero.facing=direction.normalized()
			if not action_buffer.is_empty():
				var queued: Dictionary=simulation.request_action(action_buffer.action,action_buffer.aim)
				if queued.accepted: _consume_action_buffer()
			if attacking and action_buffer.is_empty() and simulation.hero.dash_left<=0: _perform_action("attack","",false)
			simulation.step(dt)
			# Inclusive buffer expiry: retry after cooldown/locks advanced, then age in
			# authoritative world time. Hitstop cannot silently consume the buffer.
			if not action_buffer.is_empty():
				var after_step: Dictionary=simulation.request_action(action_buffer.action,action_buffer.aim)
				if after_step.accepted: _consume_action_buffer()
				else:
					action_buffer.left-=maxf(0,simulation.clock.world_time-world_before)
					if action_buffer.left<=0.0000001: action_buffer.clear()
		elif simulation.phase in ["preparation","victory"]: simulation.free_move(dt,move)
	if simulation.phase=="victory" and not simulation.paused and auto_waves.button_pressed:
		intermission_left=maxf(0,intermission_left-dt)
		if intermission_left<=0: start_room()
	environment.follow(simulation.hero.position,dt)
	if camera_kick>0:
		camera.position+=Vector3(sin(Time.get_ticks_msec()*0.081),0,cos(Time.get_ticks_msec()*0.067))*camera_kick*0.7
	siege_vfx.set_process(not simulation.paused and not stopping)
	if is_instance_valid(state_vfx): state_vfx.set_process(not simulation.paused and not stopping)
	_sync_views(0 if simulation.paused else dt,maxf(0,simulation.clock.world_time-world_before))
	if not simulation.paused and not stopping: _step_effects(dt)
	hud_elapsed+=dt
	if hud_elapsed>=1.0/12.0 or hud_phase!=simulation.phase or hud_revision!=int(ledger.model.state.revision):
		hud_elapsed=0.0
		_present()

func _request(request: Dictionary) -> void: call_deferred("_execute_ui_request",request.duplicate(true))
func _execute_ui_request(request: Dictionary) -> void:
	var result: Dictionary={"accepted":false,"reason":"stage_not_available"}
	if request.action=="ability": result=_perform_action(str(request.slot_id).to_lower(),request.command_id,false)
	elif request.action=="use_item": result=consumers.use_recovery(simulation,ledger.model,request.command_id,int(request.get("uid",-1)))
	controller.complete_combat_request(request,result)
func _perform_action(action: String, command_id := "", notify := true) -> Dictionary:
	if simulation.paused: return {"accepted":false,"reason":"paused"}
	action_serial+=1
	var id: String=command_id
	if id.is_empty() and notify: id=run_id+"/input-"+str(action_serial)
	if action=="shift":
		# Resolve this press from the current held-key state, not the previous
		# physics frame (press/release + Shift can arrive within the same frame).
		simulation.hero.move_intent=Vector3(float(held_keys.get(KEY_D,false))-float(held_keys.get(KEY_A,false)),0,float(held_keys.get(KEY_S,false))-float(held_keys.get(KEY_W,false))).limit_length(1)
	var result: Dictionary=simulation.request_action(action,_aim_point(),id)
	if result.accepted and action=="shift" and action_buffer.get("action","")=="attack": action_buffer.clear()
	if result.accepted and action=="attack" and result.get("reason","")=="dash_attack": action_buffer.clear()
	if notify or result.accepted: last_action_receipt={"action":action,"result":result.duplicate(true),"command_id":id}
	if notify and not result.accepted:
		var short_cooldown: bool=result.reason=="cooldown" and float(simulation.hero.cooldowns.get(action,999))<=0.16
		if action in ["q","e","r","shift","attack"] and (result.reason=="action_locked" or short_cooldown):
			action_buffer={"action":action,"aim":_aim_point(),"left":0.16}
			result["buffered"]=true
		else: live_hud.adapter.feedback({"text":controller.reason_text(result.reason)})
	return result
func _consume_action_buffer() -> void:
	# A quick buffered E1 tap must preserve the release that arrived before acceptance.
	if action_buffer.get("action","")=="e" and action_buffer.get("released",false) and simulation.hero.cast_state.has("e1"):
		simulation.request_action("e_release",action_buffer.aim)
	action_buffer.clear()
func _growth_completed(request: Dictionary,result: Dictionary) -> void:
	audio_router.ui(request,result)
	if result.accepted: _sync_growth_to_combat()
func _sync_growth_to_combat() -> void:
	simulation._sync_loadout_from_ledger()
	consumers.sync_stats(simulation,ledger.model)
	simulation.hero.xp_progress=ledger.model.state.xp
	growth_revision=int(ledger.model.state.revision)
	growth_model_id=ledger.model.get_instance_id()
	simulation.hero.gold=ledger.model.snapshot().gold
func _credit_kill(event: Dictionary) -> Dictionary:
	if event.get("combat_level_id","")!=simulation.combat_level_id: return {"accepted":false,"reason":"wrong_room"}
	var enemy: Dictionary=simulation.enemy_by_id(event.target)
	if enemy.is_empty() or not enemy.dead: return {"accepted":false,"reason":"not_dead"}
	var id: String=run_id+"/"+enemy.actor_id
	var reward: Array={"boss":[300,160],"elite":[100,80],"armored":[35,20]}.get(enemy.kind,[20,12])
	return ledger.model.command("reward:"+id,"reward_minion",{"event_id":id,"room":simulation.combat_level_id,"gold":reward[0],"xp":reward[1]})
func _encounter_finished(state: Dictionary) -> void:
	if state.phase=="victory" and act_trial.active and not test_mode:
		var completion:Dictionary=act_trial.record_clear(simulation.combat_level_id,run_id,ledger.model)
		if not completion.accepted:reward_errors.append({"source":"act_completion","reason":completion.reason})
		elif act_trial.completed:live_hud.adapter.feedback({"text":"断门关一幕试炼完成；已按真实幕通关结算"})
		act_trial.save_to(ledger.model)
	if views.has("xuanlei"):
		views.xuanlei.timing_active=false
		views.xuanlei.event_left=0
	attacking=false
	action_buffer.clear()
	held_keys.clear()
	if state.phase=="true_dead":
		ledger.command("life_state",{"dead":true})
		ledger.model.command("death:"+run_id+"/"+str(wave_number),"death_penalty",{"event_id":run_id+"/"+str(wave_number)})
	call_deferred("_present")
func _kills() -> int:
	var n:=0
	for e in simulation.enemies:
		if e.dead:n+=1
	return n
func _present() -> void:
	if not is_instance_valid(start_button): return
	hud_phase=simulation.phase
	hud_revision=int(ledger.model.state.revision)
	var h: Dictionary=simulation.hero.snapshot()
	var skills:Dictionary={}
	var resource:Dictionary={}
	for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"],["Shift","shift"]]:
		var slot:String=pair[1]
		var data:Dictionary={"cooldown":h.cooldowns[slot],"underlying_cooldown":h.cooldowns[slot],"reason":"就绪" if simulation.phase=="combat" else "战后冻结"}
		if float(h.cooldowns[slot])>0:data.reason="冷却中"
		if slot=="e" and h.cast_state.has("e1"):
			data.cooldown=0.0;data.recast=true;data.recast_window=h.cast_state.e1.left;data.reason="防御中 · 松开E反击"
		if slot=="r" and h.cast_state.has("r1"):
			data.cooldown=0.0;data.recast=true;data.recast_window=h.cast_state.r1.left;data.reason="背城中 · 再按R释放城压"
		if slot=="r" and h.cast_state.has("r2"):
			var state:Dictionary=h.cast_state.r2
			data.charges=state.maximum-state.count;data.max_charges=state.maximum;data.recast_window=state.left
			resource={"name":"叩关剩余次数","current":data.charges,"max":state.maximum}
			if h.cast_state.has("r2_charge"):
				data.cooldown=h.cast_state.r2_charge.left+h.cast_state.r2_charge.get("windup",0.0);data.reason="叩关冲锋中"
			else:
				data.cooldown=0.0;data.recast=true;data.reason="剩余%d次 · 按R继续冲锋（%.1f秒）"%[data.charges,state.left]
		if slot=="q" and h.loadout.q=="q2" and h.ranks.q>0 and simulation.hx("double_chain"):
			data.charges=simulation.chain_charges;data.max_charges=int(simulation.hv("double_chain"))
			data.reason="锁链储能 %d/%d"%[data.charges,data.max_charges]
		if simulation.phase!="combat":data.reason="战后冻结 · "+data.reason
		if h.dead:data.reason="已死亡"
		elif simulation.paused:data.reason="暂停 · "+data.reason
		skills[pair[0]]=data
	controller.present_combat({"hp":h.hp,"hp_max":h.max_hp,"room":("独立测试" if test_mode else act_trial.label() if act_trial.active else "玄垒自由竞技场")+" · %d/%d" % [_kills(),simulation.enemies.size()],"wave":str(wave_number),"skills":skills,"phase":simulation.phase,"shield":h.get("shield",0),"stats":{"AD":h.ad,"AP":simulation.hero.stats.ap,"defense":h.defence,"attack_speed":h.attack_speed,"move_speed":h.move_speed,"crit_chance":simulation.hero.stats.crit_chance},"status_effects":simulation.status_effects(),"resource":resource})
	start_button.text="35%生命续战 · 保留CD与账本" if simulation.phase=="true_dead" else "开始第%d波 · 同一竞技场" % (wave_number+1)
	if act_trial.active and simulation.phase!="true_dead":start_button.text="试炼完成 · 返回自由竞技场" if act_trial.completed else "进入 "+str(act_trial.room_data().title)
	mode_select.visible=simulation.phase=="preparation" and wave_number==0 and not test_mode and not live_hud.shade.visible
	if simulation.phase=="victory" and auto_waves.button_pressed: start_button.text+=" · %.1fs" % intermission_left
	training_button.visible=simulation.phase in ["preparation","victory"] and not live_hud.shade.visible
	density_select.visible=training_button.visible and training_open
	range_guides.visible=density_select.visible
	range_guides.disabled=not test_mode
	health_values.visible=range_guides.visible
	health_values.disabled=not test_mode
	density_select.disabled=not test_mode
	auto_waves.visible=density_select.visible
	start_button.visible=simulation.phase in ["preparation","victory","true_dead"] and not live_hud.shade.visible
	mute_button.visible=not live_hud.shade.visible
	help_text.visible=start_button.visible
	help_text.text="WASD 移动 · 左键 攻击 · Q/E/R · Shift 无敌冲刺\n冲刺中按左键：一次门盾突击（0.18秒窗口）"
	attack_status.visible=simulation.phase=="combat" and not live_hud.shade.visible and not live_hud.panel.visible
	var attack_cd: float=simulation.hero.cooldowns.attack
	attack_status.text=(attack_result if attack_result_left>0 else "左键 普攻 · 就绪" if attack_cd<=0 else "普攻 · %.1fs"%attack_cd)+("   Shift 无敌冲刺 · 左键冲刺攻击" if simulation.hero.dash_left>0 else "")
	attack_status.modulate=Color("b8eee1") if attack_cd<=0 else Color("a1b0b5")
	attack_status.tooltip_text="普攻测试初值：基础间隔0.70秒；前两段57.4%AD，第三段68.88%AD。攻速缩短间隔与动作，暴击/吸血照常结算；前摇可Shift取消；冲刺中按左键触发一次门盾突击（普攻基准伤害×1.15），每目标仅命中一次。"
	help_text.tooltip_text="战后可走动；HP/CD/资源冻结 · P商店/自由测试 · K修习"
	if not live_hud.shade.visible and get_viewport().gui_get_focus_owner()==null and start_button.visible: start_button.grab_focus()
func _sync_views(dt: float, world_dt := -1.0) -> void:
	var state: Dictionary=simulation.snapshot()
	var bolts: Array=state.get("projectiles",[])
	projectile_view.multimesh.visible_instance_count=0 # Textured authored projectile replaces primitive mesh.
	enemy_combat_vfx.sync_projectiles(bolts)
	if enemy_combat_vfx.has_method("sync_hostile_zones"): enemy_combat_vfx.sync_hostile_zones(state.get("zones",[]))
	for i in range(mini(256,bolts.size())):
		projectile_view.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,bolts[i].position+Vector3(0,1.0,0)))
	var actors: Array=state.enemies.duplicate()
	var hero: Dictionary=state.hero.duplicate()
	hero.kind="hero"
	enemy_combat_vfx.sync_hero(hero)
	enemy_combat_vfx.sync_enemies(state.enemies)
	if not simulation.paused: enemy_combat_vfx.step(maxf(0,world_dt) if world_dt>=0 else dt)
	actors.append(hero)
	contact_shadows.visible=environment.software_renderer
	var grounded: Array=[]
	for actor in actors:
		if not actor.get("dead",false): grounded.append(actor)
	contact_shadows.multimesh.visible_instance_count=mini(181,grounded.size())
	for i in range(mini(181,grounded.size())):
		var actor: Dictionary=grounded[i]
		var scale_factor:float=(1.3 if actor.get("kind","") in ["hero","elite","boss"] else 0.8)*float(actor.get("model_scale",actor.get("common_model_scale",1.0)))
		contact_shadows.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(scale_factor,1,scale_factor)),actor.position+Vector3(0,0.038,0)))
	var present: Array=[]
	for actor in actors:
		present.append(actor.actor_id)
		if not views.has(actor.actor_id):
			var view=ActorView.new() if actor.kind=="hero" else EnemyActorView.new()
			add_child(view)
			view.setup(actor.kind,visual_assets.get(actor.kind,null))
			views[actor.actor_id]=view
			if actor.kind=="hero":
				state_vfx=preload("res://assets/xuanlei/vfx/siege_state.tscn").instantiate()
				view.add_child(state_vfx)
		var actor_dt: float=world_dt if simulation.phase=="combat" and world_dt>=0 else dt
		views[actor.actor_id].detail_labels=test_mode and health_values.button_pressed
		views[actor.actor_id].sync(actor,actor_dt,simulation.paused or (simulation.phase!="combat" and actor.kind!="hero"),dt)
		if actor.kind not in ["hero","elite","boss"] and actor.position.distance_squared_to(hero.position)>=100: views[actor.actor_id].health.visible=false
	if enemy_combat_vfx.has_method("sync_actor_views"): enemy_combat_vfx.sync_actor_views(views)
	if views.has("xuanlei"):
		var attack_delta:float=0.0 if simulation.paused else dt if views.xuanlei.anim=="dash_attack" else maxf(0.0,world_dt) if simulation.phase=="combat" and world_dt>=0 else dt
		attack_vfx.sample_weapon(views.xuanlei,attack_delta)
		attack_vfx._process(attack_delta)
	var common_dt:float=0.0 if simulation.paused else maxf(0.0,world_dt) if simulation.phase=="combat" and world_dt>=0 else dt
	common_hex_vfx.sync(state,common_dt,views)
	for actor in actors:
		var actor_view=views[actor.actor_id]
		if is_instance_valid(actor_view.visual):
			actor_view.visual.visible=not (actor.get("dead",false) and common_hex_vfx.suppressed_corpses.has(actor.actor_id))
	was_dashing=simulation.hero.dash_left>0
	siege_vfx.sync_charge(hero.position,hero.facing,hero.cast_state if simulation.phase=="combat" else {},dt,state.enemies)
	if is_instance_valid(state_vfx):
		state_vfx.set_passive(int(str(hero.loadout.passive).right(1))-1 if hero.ranks.passive>0 else -1,hero.bone_stacks,float(hero.get("retaliation_left",0))>0,clampf((0.5-hero.hp/hero.max_hp)*2,0,1))
		state_vfx.set_guard(hero.cast_state.has("e1"))
		state_vfx.set_field(hero.cast_state.has("e3"),float(hero.cast_state.get("e3",{}).get("radius",4.0)))
		if state_vfx.has_method("set_e3_shield"):
			var e3_amount:float=0.0
			var e3_initial:float=0.0
			for shield_id in hero.shields:
				if str(shield_id).begins_with("e3:"):
					e3_amount+=float(hero.shields[shield_id].amount)
					e3_initial+=float(hero.shields[shield_id].get("initial_amount",hero.shields[shield_id].amount))
			state_vfx.set_e3_shield(e3_amount>0,e3_amount/maxf(.001,e3_initial))
		state_vfx.set_fortress(hero.cast_state.has("r1"),float(hero.cast_state.get("r1",{}).get("pressure",0))/hero.max_hp)
	for id in views.keys():
		if not id in present: views[id].queue_free(); views.erase(id)
func _on_combat_event(event: Dictionary) -> void:
	if event.kind in ["damage","kill"] and ledger.model.has_method("record_battle_event"):
		ledger.model.record_battle_event(simulation,event,run_id)
	if str(event.kind).begins_with("common_hex_") or (event.kind=="damage" and str(event.get("source","")).begins_with("common_")):
		# Presentation reads the live event target once; avoid a full progression/deep snapshot per hit.
		var friendlies:Array=[]
		for ally in simulation.allies:friendlies.append(ally.snapshot())
		var scope:Dictionary={"room_id":simulation.room_id,"generation":simulation.encounter_generation,"run_id":run_id}
		common_hex_vfx.combat_event(event,{"hero":simulation.hero.snapshot(),"enemies":simulation.enemies,"allies":friendlies,"common_hexes":scope},views)
	audio_router.combat(event)
	enemy_combat_vfx.play_event(event)
	if event.kind in ["encounter_started","encounter_finished"]:
		enemy_combat_vfx.clear();attack_vfx.clear_transients()
	siege_vfx.combat_event(event,simulation.hero.position,simulation.hero.facing)
	if event.kind=="kill":
		var receipt: Dictionary=_credit_kill(event)
		if not receipt.accepted: reward_errors.append(receipt)
	if event.kind=="damage":
		var amount: float=event.get("amount",0)
		var hero_hit: bool=event.target=="xuanlei"
		if amount<=0 and float(event.get("absorbed",0))<=0: return
		if not hero_hit and str(event.get("source","")) in ["attack","dash_attack"]:
			var direction:Vector3=event.get("direction",event.position-event.get("source_position",simulation.hero.position))
			if direction.length_squared()<.001:direction=simulation.hero.facing
			var material:String={"armored":"metal","elite":"metal","boss":"stone","minion":"stone","pouncer":"stone","ranged":"metal","pitcher":"stone","support":"stone"}.get(str(event.get("enemy_kind","")),"stone")
			attack_vfx.contact(event.position,direction.normalized(),int(event.get("combo",1)),material,event.source=="dash_attack",int(event.get("cast_id",-1)))
		if views.has(event.target):
			var direction: Vector3=event.get("direction",(event.position-simulation.hero.position).normalized())
			var heavy_contact:bool=str(event.get("source","")) in ["q1","q1_echo","dash_attack"] or (str(event.get("source",""))=="attack" and int(event.get("combo",1))==3)
			views[event.target].hit_reaction(direction,hero_hit,heavy_contact and amount>0)
		if amount>0:
			_floating_text(("−" if hero_hit else "")+str(roundi(amount)),event.position,Color("ff7666") if hero_hit else Color("fff1b6") if event.get("critical",false) else Color("fffaf0"),hero_hit)
			if str(event.get("source","")) not in ["q1","q1_echo","attack","dash_attack"]:
				_contact_spark(event.position,Color("ff7659") if hero_hit else Color("fff1b4"))
		elif hero_hit:
			_floating_text("护盾 "+str(roundi(event.get("absorbed",0))),event.position,Color("7acfe7"),true)
		if hero_hit and amount>0:
			_present() # HP feedback must share the authoritative damage frame.
			hurt_tint.color.a=0.10
			camera_kick=0.12
			hitstop_left=maxf(hitstop_left,0.025)
		elif not hero_hit and str(event.get("source","")) in ["attack","dash_attack","q1","q3","e1","r1","r2_final"] and int(event.get("cast_id",-1))!=last_hitstop_cast:
			last_hitstop_cast=int(event.get("cast_id",-1))
			var light_basic:bool=event.source=="attack" and int(event.get("combo",1)) in [1,2]
			hitstop_left=maxf(hitstop_left,0.035 if light_basic else 0.045)
		return
	if event.kind=="attack_cancelled":
		for id in event.get("cast_ids",[]):attack_vfx.cancel_attack(int(id))
		if views.has("xuanlei"): views.xuanlei.event_left=0;views.xuanlei.timing_active=false
	if event.kind=="dash": dash_feedback_left=0.18
	var clip: String={"attack_started":"attack_%d" % maxi(1,int(event.get("combo",1))),"dash":"dash","q1_windup":"q1","q2_windup":"q2","q3_windup":"q3","e1_guard_started":"e1_guard","e1_release":"e1_release","e2_charge_started":"e2","e3_aura_started":"e3","ultimate_started":"r1_start" if event.get("candidate","")=="r1" else "r2_charge","r1_release":"r1_end","r2_charge_started":"r2_charge","r2_finish":"r2_end"}.get(event.kind,"")
	if views.has("xuanlei"):
		if event.has("animation"): views.xuanlei.combat_event(event)
		elif not clip.is_empty(): views.xuanlei.event(clip,maxf(0.6,float(event.get("duration",0.6))))
		if event.kind in ["attack_started","dash_attack_started"]:
			attack_vfx.begin_attack("dash_attack" if event.kind=="dash_attack_started" else "attack_%d"%int(event.get("combo",1)),int(event.get("cast_id",-1)),views.xuanlei)
	if event.kind=="attack_impact":
		var hit: bool=int(event.get("hit_count",0))>0
		# Basic/dash presentation comes only from the socket-traced attack module.
		attack_result="普攻 命中" if hit else "普攻 挥空"
		attack_result_left=0.45
	elif event.kind=="dash_attack_started":
		attack_result="冲刺攻击"
		attack_result_left=0.45
	elif event.kind=="dash_attack_hit":
		attack_result="冲刺攻击 命中"
		attack_result_left=0.45

func _floating_text(text: String, at: Vector3, tint: Color, hero_hit := false, lifetime := 0.72) -> void:
	if effects.size()>70: return
	var label:=Label3D.new()
	label.text=text
	label.font=preload("res://assets/ui/NotoSansCJKsc-Regular.otf")
	label.font_size=38 if hero_hit else 34
	label.pixel_size=0.020
	label.outline_size=7
	label.modulate=tint
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=true
	add_child(label)
	label.position=at+Vector3(float(simulation.sequence%3-1)*0.16,2.35 if hero_hit else 2.05,0)
	effects.append({"node":label,"life":lifetime,"total":lifetime,"text":true})

func _contact_spark(at: Vector3, tint: Color) -> void:
	for angle in [-0.65,0.65]:
		var shape:=QuadMesh.new()
		shape.size=Vector2(0.10,0.90)
		var n:=MeshInstance3D.new()
		n.mesh=shape
		var mat:=Stage.material(tint,0.5,0,1.2)
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		n.material_override=mat
		add_child(n)
		n.position=at+Vector3(0,1.15,0)
		n.rotation.z=angle
		effects.append({"node":n,"life":0.10,"total":0.10})

func _step_effects(dt: float) -> void:
	for effect in effects:
		effect.life-=dt
		if effect.get("text",false):
			effect.node.position.y+=dt*0.85
			effect.node.modulate.a=clampf(effect.life/0.20,0,1)
		else: effect.node.scale=Vector3.ONE*(1+0.3*(1-effect.life/effect.total))
	for i in range(effects.size()-1,-1,-1):
		if effects[i].life<=0: effects[i].node.queue_free();effects.remove_at(i)
func integration_snapshot() -> Dictionary:
	return {"combat":simulation.snapshot(),"growth":ledger.model.snapshot(),"hud":live_hud.adapter.state,"wave_number":wave_number,"room_number":room_number,"test_mode":test_mode,"panel_open":live_hud.shade.visible,"attacking":attacking,"reward_errors":reward_errors.duplicate(true),"last_action_receipt":last_action_receipt.duplicate(true),"checkpoint":"xuanlei-local"}
func integration_report() -> String: return JSON.stringify(integration_snapshot())

func start_render_probe(count: int, seconds := 12.0) -> Dictionary:
	if simulation.phase not in ["preparation","victory"]: return {"accepted":false,"reason":"unsafe_phase"}
	var probe=load("res://tests/xuanlei/render_probe.gd").new()
	add_child(probe)
	return probe.begin(self,count,seconds)

func _diagnostics_root() -> String:
	# The editor executable can run a PCK too; its editor feature remains true.
	# A packed resource tree is read-only, regardless of the executable flavor.
	return "res://.local" if OS.has_feature("editor") and not FileAccess.file_exists("res://project.binary") else "user://diagnostics"
