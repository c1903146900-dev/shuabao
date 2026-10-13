extends RefCounted
## Read only: the existing domain and actor accumulator remain the sole authority.
const AUTHORING := "res://data/combat/ultimate_presentation_authoring.json"
const SOURCE_SCRIPT := "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const METADATA := "res://tests/ink_ultimate_presentation_art_20261006/dual_v03/clip_metadata.json"
const METADATA_SHA := "4a8493392e931e043952029a2432f537e7945f2d81a4db102d3fa04661dae5ca"
var metadata: Dictionary={}
var durations: Dictionary={}
var metadata_valid: bool=false
var _source: WeakRef
var _token: Dictionary = {}
var _scope: Dictionary = {}
var _actor_origin: float = 0.0
var duration: float = 0.0

func _init() -> void:
 var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(AUTHORING))
 var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(METADATA))
 if not data is Dictionary or not raw is Dictionary or FileAccess.get_sha256(METADATA)!=METADATA_SHA:return
 metadata=raw
 for ability: String in ["yanguizhou_r1","yanguizhou_r2"]:
  var seconds: float=float(data.get("presentation_seconds",{}).get(ability,0.0))
  if seconds<=0.0 or seconds!=float(metadata.clips[ability].seconds):return
  durations[ability]=seconds
 metadata_valid=durations.size()==2
 duration=float(durations.get("yanguizhou_r2",0.0))

func bind_source(source: Node) -> Dictionary:
 reset()
 _source=null
 if not metadata_valid:return {"accepted":false,"reason":"dual_source_clip_metadata_invalid"}
 if not is_instance_valid(source):
  return {"accepted":false, "reason":"exact_r2_ordinary_sim_required"}
 var source_script: Script=source.get_script() as Script
 if source_script==null or source_script.resource_path != SOURCE_SCRIPT:
  return {"accepted":false, "reason":"exact_r2_ordinary_sim_required"}
 _source = weakref(source)
 return {"accepted":duration > 0.0, "reason":"read_only_domain_and_actor_clock", "duration":duration}

func reset() -> void:
 _token.clear()
 _scope.clear()
 _actor_origin = 0.0

func _same_token(a: Dictionary, b: Dictionary) -> bool:
 if a.size() != b.size(): return false
 for key: Variant in a:
  if not b.has(key) or typeof(a[key]) != typeof(b[key]) or a[key] != b[key]: return false
 return true

func read(ink: Dictionary, current_upper: String="", dash_override: bool=false) -> Dictionary:
 var shown: Dictionary = ink.get("ultimate_presentation", {})
 var actor_now: float = float(shown.get("actor_motion_time", -1.0))
 var result: Dictionary = {"active":false, "actor_time":actor_now, "duration":duration, "token":{}, "reason":"unbound"}
 if _source == null or not is_instance_valid(_source.get_ref()):
  reset()
  return result
 var source: Node = _source.get_ref()
 if not is_finite(actor_now) or actor_now < 0.0 or not is_finite(duration) or duration <= 0.0:
  reset(); result.reason = "invalid_actor_clock_or_authoring"; return result
 var current: Dictionary = source.ink_presenter_snapshot()
 if current.get("scope", {}) != ink.get("scope", {}) or current.get("ultimate_presentation", {}) != shown:
  reset(); result.reason = "stale_snapshot_or_scope"; return result
 var token: Dictionary = shown.get("token", {})
 if not bool(shown.get("active", false)) or not durations.has(str(token.get("ability_id", ""))):
  reset(); result.reason = "inactive_or_other_ability"; return result
 var ability: String=str(token.ability_id)
 duration=float(durations[ability]);result.duration=duration
 var clip: String=str(metadata.clips[ability].clip)
 var domain: Dictionary = source.clock.domain.snapshot()
 var owner_scope: Dictionary = domain.get("scope", {})
 for key: String in ["owner_id", "room_id", "generation"]:
  if not token.has(key) or not owner_scope.has(key) or typeof(token[key]) != typeof(owner_scope[key]) or token[key] != owner_scope[key]:
   reset(); result.reason = "stale_token_scope"; return result
 if token.get("actor_id", "") != source.hero.actor_id or token.get("room_id", "") != source.room_id or token.get("generation", -1) != source.encounter_generation:
  reset(); result.reason = "wrong_actor_or_room"; return result
 var record: Dictionary = domain.get("presentations", {}).get(token.actor_id, {})
 if not _same_token(record.get("token", {}), token) or not source.clock.domain.is_invulnerable(token):
  reset(); result.reason = "token_not_live"; return result
 # Each presenting actor advances at real rate. This is the authority's exact
 # elapsed only while this exact token is live, never world_time / slow_factor.
 var show: Dictionary = source.get("_current_show")
 if not _same_token(show.get("token", {}), token) or bool(show.get("cancelled", false)) or float(show.get("end", -1.0)) != float(record.expires_at) or absf(float(show.get("end", 0.0)) - float(show.get("start", 0.0)) - duration) > 0.000001:
  reset(); result.reason = "show_record_or_config_disagrees"; return result
 var authority_elapsed: float = float(domain.active_real_time) - float(show.start)
 if not is_finite(authority_elapsed) or authority_elapsed < 0.0 or authority_elapsed >= duration:
  reset(); result.reason = "outside_authority_window"; return result
 if not _same_token(_token, token) or _scope != ink.scope:
  _token = token.duplicate(true)
  _scope = ink.scope.duplicate(true)
  _actor_origin = actor_now - authority_elapsed
 var actor_elapsed: float = actor_now - _actor_origin
 if absf(actor_elapsed - authority_elapsed) > 0.000001:
  reset(); result.reason = "actor_domain_elapsed_disagrees"; return result
 var input_phase: String=str(ink.get("input",{}).get("phase",""))
 var owns_q: bool=input_phase in ["drawing","frozen"]
 var dash: bool=dash_override or float(ink.get("hero",{}).get("dash_left",0.0))>0.0
 var priority: String="Shift" if dash else current_upper if not current_upper.is_empty() else "Q1" if owns_q else ""
 var weight: float=0.0 if not priority.is_empty() else 1.0-smoothstep(0.9*duration,duration,actor_elapsed)
 result.merge({"ability_id":ability,"clip":clip,"upper_weight":weight,"priority_owner":priority,
  "normal_movement_preserved":true,"root_facing_written":false,"Godot_clip_import_verified":false,
  "active":true, "token":token.duplicate(true), "elapsed":actor_elapsed,
  "actor_origin":_actor_origin, "authority_elapsed":authority_elapsed,
  "expires_at":record.expires_at, "paused":source.paused, "reason":"exact_live_token_actor_time"}, true)
 return result
