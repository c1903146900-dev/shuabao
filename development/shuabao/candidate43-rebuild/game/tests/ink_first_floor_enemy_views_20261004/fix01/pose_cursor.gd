extends RefCounted
## View-local sampling only; a repeated source time never advances gait/death.
const Catalog = preload("res://tests/ink_first_floor_enemy_views_20261004/asset_catalog.gd")
const DeathClock = preload("res://tests/ink_victory_death_pose_20261004/death_clock.gd")
const CORPSE_COMBAT_SECONDS := 3.0 # Existing xuanlei_actor_view.gd lifecycle.
var config: Dictionary = {}
var _last_time := -1.0
var _last_position := Vector3.ZERO
var _gait := 0.0
var _moving := false
var _death: RefCounted = DeathClock.new()
var report: Dictionary = {}

func configure(kind: String) -> void:
	config = Catalog.entry(kind)

func sample(actor: Dictionary, frame: Dictionary) -> Dictionary:
	var state: Dictionary = actor.state
	var now := float(frame.world_time)
	var at: Vector3 = state.position
	if config.is_empty(): return {"status":"HOLD_unknown_role"}
	if _last_time >= 0.0 and now > _last_time:
		var distance := _last_position.distance_to(at)
		_moving = distance > 0.0005
		_gait += distance / float(config.gait_speed)
	if now > _last_time:
		_last_position = at; _last_time = now
	var clip := str(config.locomotion_clip) if _moving else "idle"
	var pose_time := _gait if _moving else now
	var dead := bool(state.dead)
	var contact: Dictionary = actor.get("contact", {})
	var contact_at := float(contact.get("world_time", -100.0))
	var flash := 0.12 if now - contact_at >= 0.0 and now - contact_at < 0.075 else 0.0
	var cleanup := false
	var death_report: Dictionary = {}
	var phase := str(state.get("state", ""))
	var attack: Dictionary = config.clips.attack
	var contact_marker := float(attack.events.contact)
	if dead:
		clip = "death"
		var native_age := maxf(0.0, now - float(actor.dead_at))
		var presentation: Dictionary = frame.get("presentation", {}).duplicate(true)
		var identity := {"scope":frame.scope.duplicate(true),"token":actor.token}
		var matching: bool = int(presentation.get("instance_id", -1)) == int(frame.scope.source_instance) and presentation.get("scope", {}) == {"room_id":frame.scope.room_id,"generation":frame.scope.generation}
		presentation["phase"] = str(frame.phase)
		var blocked: bool = bool(frame.paused) or bool(frame.hero_dead) or (frame.phase != "combat" and not matching) or bool(presentation.get("loading", false)) or bool(presentation.get("finished", false)) or bool(presentation.get("shop_open", false))
		death_report = _death.sample(identity, now, native_age, presentation, blocked, contact_at, float(config.clips.death.duration_s))
		pose_time = float(death_report.get("death_pose_time", 0.0))
		flash = float(death_report.get("hit_flash", 0.0))
		# In combat keep the source corpse for the production 3s window. Victory
		# reuses the existing safe-clock completion and holds final pose to room exit.
		cleanup = frame.phase == "combat" and native_age >= CORPSE_COMBAT_SECONDS
	elif phase == "warning":
		clip = "leap" if config.kind == "pouncer" else "attack"
		var end := float(config.clips.leap.events.takeoff) if config.kind == "pouncer" else contact_marker
		pose_time = end * clampf(float(state.get("warning_progress", 0.0)), 0.0, 1.0)
	elif phase == "pounce" and config.kind == "pouncer":
		clip = "leap"
		pose_time = lerpf(float(config.clips.leap.events.takeoff), float(config.clips.leap.events.contact), clampf(1.0 - float(state.timer) / 0.40, 0.0, 1.0))
	elif phase == "recover":
		clip = "leap" if config.kind == "pouncer" else "attack"
		var selected: Dictionary = config.clips[clip]
		pose_time = lerpf(float(selected.events.contact), float(selected.duration_s), clampf(1.0 - float(state.timer) / float(config.director_recovery), 0.0, 1.0))
	elif now - contact_at >= 0.0 and now - contact_at < 0.20 and (float(state.get("stun_left", 0.0)) > 0.0 or bool(state.get("carried", false))):
		clip = str(config.hurt_clip); pose_time = now - contact_at
	var hp := float(state.hp)
	var maximum := float(state.max_hp)
	var shield := float(state.get("shield", 0.0))
	report = {"status":"ready","token":actor.token,"actor_id":state.actor_id,"kind":state.kind,"clip":clip,"time":pose_time,"loop":clip in ["idle","run","walk"],"position":at,"facing":state.get("facing",Vector3.FORWARD),"model_scale":float(state.get("common_model_scale",1.0)),"source_radius":state.get("radius",0.0),"dead":dead,"cleanup":cleanup,"hp":hp,"max_hp":maximum,"shield":shield,"has_shield":state.has("shield"),"hp_fraction":clampf(hp / maxf(0.001,maximum),0.0,1.0),"shield_fraction":clampf(shield / maxf(0.001,maximum),0.0,1.0),"hit_flash":flash,"death":death_report,"contact":contact.duplicate(true),"gait":_gait}
	return report.duplicate(true)
