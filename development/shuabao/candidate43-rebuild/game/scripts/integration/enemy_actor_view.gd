extends "res://scripts/integration/xuanlei_actor_view.gd"
## Enemy presentation contract: body/weapon anticipation and exact phase timing.
## Never advances enemy timers, displacement, attack eligibility, collision, or damage.
var role_pose_clip := "idle"
var role_pose_time := 0.0
var role_gait_time := 0.0
var role_state := ""
var role_state_age := 0.0
var role_hurt_left := 0.0
var phase_evidence: Array[Dictionary] = []
var role_status: Label3D
const ROLE_SPEED := {"minion":2.8,"pouncer":4.5,"armored":2.4,"ranged":2.6,"pitcher":2.3,"support":2.6,"elite":2.0,"boss":2.0}

func setup(actor_kind: String, packed: PackedScene = null) -> void:
	if packed==null:
		var asset: String="res://assets/enemies/siege_brood/%s/%s.glb"%[actor_kind,actor_kind]
		if ResourceLoader.exists(asset):packed=load(asset)
		elif actor_kind in ["minion","elite","boss"]:
			# Preserve the authored arena models when a Brood replacement is absent.
			var legacy_asset: String="res://assets/arena/enemies/%s.glb"%actor_kind
			if ResourceLoader.exists(legacy_asset):packed=load(legacy_asset)
	super.setup(actor_kind,packed)
	var all: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/siege_brood/animation_contract.json"))
	var entry: Dictionary=all.get("enemies",{}).get(kind,{})
	if not entry.is_empty():
		animation_contract=entry.get("clips",{})
		health.position.y=float(entry.get("height_m",1.5))+.26
		base_health_height=health.position.y
		hp_fill.position.y=health.position.y-.13
		hp_back.position.y=health.position.y-.13
	for n in [warning,warning_edge,warning_back,attack_alert]:n.visible=false
	role_status=Label3D.new();role_status.font_size=18;role_status.pixel_size=.012
	role_status.billboard=BaseMaterial3D.BILLBOARD_ENABLED;role_status.outline_size=5
	role_status.position.y=health.position.y+.13;role_status.modulate=Color("e8b76f");add_child(role_status)

func hit_reaction(direction: Vector3, hero_hit: bool = false, heavy: bool = false) -> void:
	super.hit_reaction(direction,hero_hit,heavy)
	role_hurt_left=.20

func sync(s: Dictionary, dt: float, frozen := false, real_dt := -1.0) -> void:
	var actual_state: String=str(s.get("state","chase"))
	var moved: float=position.distance_to(s.get("position",position))
	var neutral: Dictionary=s.duplicate()
	# Old actor implementation remains shared for health/hit flash/corpse cleanup.
	# Removing the legacy warning state here prevents even constructing its blanket disc.
	neutral["state"]="role_presentation"
	# Alive role playback below replaces the base sample. Frozen/death paths still
	# need it; defer only pose writes, never health, recoil or blend bookkeeping.
	var replacing_clip:String=_role_sample_clip(s,actual_state,moved,dt)
	defer_pose_sample=not frozen and not bool(s.get("dead",false)) and player!=null and player.has_animation(replacing_clip)
	super.sync(neutral,dt,frozen,real_dt)
	defer_pose_sample=false
	for n in [warning,warning_edge,warning_back,attack_alert]:n.visible=false
	role_status.visible=not bool(s.get("dead",false)) and (bool(s.get("taunted",false)) or float(s.get("guard_broken_left",0))>0)
	role_status.text="破盾" if float(s.get("guard_broken_left",0))>0 else "嘲讽"
	if bool(s.get("dead",false)) or not player:return
	if frozen:return
	if actual_state!=role_state:
		role_state=actual_state;role_state_age=0.0
		if phase_evidence.size()<80:phase_evidence.append({"state":role_state,"kind":kind,"ground_warning":false})
	else:role_state_age+=dt
	role_hurt_left=maxf(0.0,role_hurt_left-dt)
	role_gait_time+=moved/maxf(.1,float(ROLE_SPEED.get(kind,2.5)))
	var attack: Dictionary=animation_contract.get("attack",{})
	var markers: Dictionary=attack.get("events",{})
	var contact: float=float(markers.get("contact",.65))
	var length: float=float(attack.get("duration_s",1.75))
	role_pose_clip="run" if moved>.0005 else "idle"
	role_pose_time=role_gait_time if role_pose_clip=="run" else anim_time
	if actual_state=="warning":
		role_pose_clip="leap" if kind=="pouncer" else "attack"
		role_pose_time=(float(animation_contract.get("leap",{}).get("events",{}).get("takeoff",.62)) if kind=="pouncer" else contact)*clampf(float(s.get("warning_progress",0)),0,1)
	elif actual_state=="pounce":
		role_pose_clip="leap"
		var leap: Dictionary=animation_contract.get("leap",{})
		var begin: float=float(leap.get("events",{}).get("takeoff",.62))
		var end: float=float(leap.get("events",{}).get("contact",1.02))
		role_pose_time=lerpf(begin,end,clampf(1.0-float(s.get("timer",.4))/.4,0,1))
	elif actual_state=="recover":
		role_pose_clip="leap" if kind=="pouncer" else "attack"
		var selected: Dictionary=animation_contract.get(role_pose_clip,{})
		var begin: float=float(selected.get("events",{}).get("contact",contact))
		var end: float=float(selected.get("duration_s",length))
		var recovery_total: float=end-begin
		role_pose_time=lerpf(begin,end,clampf(1.0-float(s.get("timer",recovery_total))/maxf(.001,recovery_total),0,1))
	elif role_hurt_left>0 and (float(s.get("stun_left",0))>0 or bool(s.get("carried",false))):
		role_pose_clip="hurt";role_pose_time=.20-role_hurt_left
	if not player.has_animation(role_pose_clip):return
	var a: Animation=player.get_animation(role_pose_clip)
	if role_pose_clip in ["idle","run"]:role_pose_time=fposmod(role_pose_time,maxf(.001,a.length))
	else:role_pose_time=clampf(role_pose_time,0,a.length)
	if is_instance_valid(skeleton):skeleton.reset_bone_poses()
	player.play(role_pose_clip);player.seek(role_pose_time,true)
	played_clip=role_pose_clip;anim=role_pose_clip;sampled_time=role_pose_time

func _role_sample_clip(s:Dictionary,actual_state:String,moved:float,dt:float)->String:
	# Match the phase priority below sync's shared-state pass. Missing custom clips
	# retain the base fallback sample instead of silently preserving an old pose.
	if actual_state=="pounce":return "leap"
	if actual_state in ["warning","recover"]:return "leap" if kind=="pouncer" else "attack"
	if role_hurt_left>dt and (float(s.get("stun_left",0))>0 or bool(s.get("carried",false))):return "hurt"
	return "run" if moved>.0005 else "idle"

func cast_socket_world() -> Vector3:
	if is_instance_valid(skeleton):
		var bone: int=skeleton.find_bone("socket_cast")
		if bone>=0:
			skeleton.force_update_all_bone_transforms()
			return skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
	return global_position+Vector3.UP*1.35-global_basis.z*.65
