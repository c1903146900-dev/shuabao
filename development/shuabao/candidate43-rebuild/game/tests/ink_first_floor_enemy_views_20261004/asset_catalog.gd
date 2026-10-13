extends RefCounted
## Asset/clip metadata only. Never overrides Director gameplay profiles.
const BROOD := "res://assets/enemies/siege_brood/animation_contract.json"
const ARENA := "res://assets/arena/enemies/animation_contract.json"
const BOSS := "res://assets/arena/enemies/boss.glb"
const ROLES := ["minion", "pouncer", "armored", "ranged", "pitcher", "support", "elite", "boss"]
const GAIT_SPEED := {"minion":2.8, "pouncer":4.5, "armored":2.4, "ranged":2.6, "pitcher":2.3, "support":2.6, "elite":2.0, "boss":2.0}
const Director = preload("res://scripts/combat/enemy_director.gd")

static func entry(kind: String) -> Dictionary:
	if kind not in ROLES: return {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA if kind == "boss" else BROOD))
	var result: Dictionary = data.enemies[kind].duplicate(true)
	result["kind"] = kind
	result["gait_speed"] = GAIT_SPEED[kind]
	result["director_recovery"] = float(Director.PROFILES[kind][7])
	result["director_warning"] = float(Director.PROFILES[kind][6])
	result["locomotion_clip"] = "walk" if kind == "boss" else "run"
	if kind == "boss":
		result["asset"] = BOSS
		result["height_m"] = result.nominal_model_height_m
		result["clips"] = {
			"attack":{"duration_s":result.attack_duration_s,"events":{"contact":result.warning_s}},
			"death":{"duration_s":result.death_duration_s},
			"hurt":{"duration_s":result.hit_duration_s}}
		result["hurt_clip"] = "hit"
	else: result["hurt_clip"] = "hurt"
	return result
