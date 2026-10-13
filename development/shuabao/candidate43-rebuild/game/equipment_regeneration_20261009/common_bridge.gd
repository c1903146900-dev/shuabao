extends "res://equipment_pursuit_20261009/common_bridge.gd"
## One original runtime/clock and the whole B02/P2/E3/Boat/Rain chain. Only the
## derived regen rate changes; the core's single natural regeneration heal stays.
var _e03_episode: Dictionary = {}
var _e03_interval: Dictionary = {}
var _e03_episode_serial: int = 0
var _e03_base_regen: float = 0.0

func _e03_source_owner():
 if model == null: return null
 var owner = model.get_ref()
 if owner == null or not owner.has_method("e03_regen_effect"): return null
 return owner

func _e03_sync_episode() -> void:
 var s = sim()
 var owner = _e03_source_owner()
 if owner == null or s.phase != "combat" or s.hero.dead or not runtime.combat:
  _e03_episode = {};_e03_interval = {};return
 # A same-combat scope refresh is not a new combat episode. Wait for the
 # original runtime to bind its scope without discarding the existing start.
 if runtime.generation != s.encounter_generation or runtime.room_id != s.room_id: return
 var now: float = float(runtime.actor_time)
 var same: bool = not _e03_episode.is_empty() and is_same(_e03_episode.hero.get_ref(),s.hero) and is_same(_e03_episode.owner.get_ref(),owner) and is_same(_e03_episode.clock.get_ref(),runtime) and _e03_episode.run_id == str(owner._run_id) and _e03_episode.clock_run_id == str(runtime.run_id)
 if same and now >= float(_e03_episode.started): return
 _e03_episode_serial += 1
 _e03_episode = {"hero":weakref(s.hero),"owner":weakref(owner),"clock":weakref(runtime),"run_id":str(owner._run_id),"clock_run_id":str(runtime.run_id),"started":now,"serial":_e03_episode_serial}
 _e03_interval = {}

func e03_clock_context() -> Dictionary:
 var s = sim()
 var owner = _e03_source_owner()
 var valid: bool = owner != null and not _e03_episode.is_empty() and is_same(_e03_episode.hero.get_ref(),s.hero) and is_same(_e03_episode.owner.get_ref(),owner) and is_same(_e03_episode.clock.get_ref(),runtime) and _e03_episode.run_id == str(owner._run_id) and _e03_episode.clock_run_id == str(runtime.run_id)
 valid = valid and s.phase == "combat" and runtime.combat and not s.hero.dead and runtime.generation == s.encounter_generation and runtime.room_id == s.room_id
 return {"bound":valid,"combat":valid,"owner_alive":not s.hero.dead,"clock":"original_common_actor_time","now":float(runtime.actor_time),"combat_started_at":float(_e03_episode.started) if valid else -1.0,"episode":int(_e03_episode.serial) if valid else -1,"generation":s.encounter_generation,"room_id":s.room_id,"base_regen":_e03_base_regen}

func e03_tick_interval() -> Dictionary:
 if not runtime._tick_prepared or _e03_interval.is_empty(): return {}
 var context: Dictionary = e03_clock_context()
 if not context.bound or _e03_interval.episode != context.episode or _e03_interval.generation != context.generation or _e03_interval.room_id != context.room_id or _e03_interval.end != context.now: return {}
 return _e03_interval.duplicate(true)

func refresh_stats(detect_external_changes: bool = true) -> void:
 super.refresh_stats(detect_external_changes)
 _e03_sync_episode()
 var s = sim()
 var h = s.hero
 _e03_base_regen = float(h.stats.regen)
 var effect: Dictionary = s.e03_current_regen_effect(true) if s.has_method("e03_current_regen_effect") else {}
 h.stats.regen = _e03_base_regen*float(effect.get("applied_factor",1.0))
 # Match the original detector to the final visible projection. The next
 # refresh starts from the unmodified projected_base_stats, never this product.
 _last_stats = h.stats.duplicate(true)

func begin_tick(world_dt: float, actor_dt: float = -1.0) -> void:
 _e03_sync_episode()
 _e03_interval = {}
 var context: Dictionary = e03_clock_context()
 var duration: float = maxf(0.0,world_dt if actor_dt < 0.0 else actor_dt)
 if context.bound and not runtime._tick_prepared and is_finite(duration) and duration > 0.0:
  _e03_interval = {"episode":context.episode,"generation":context.generation,"room_id":context.room_id,"start":context.now,"end":float(context.now)+duration,"duration":duration}
 # The original method advances actor_time once then calls this refresh_stats.
 # Current source presentation defers reentrant steps in the same accumulator.
 super.begin_tick(world_dt,actor_dt)

func tick(dt: float, actor_dt: float = -1.0) -> void:
 # Natural regen has already committed. Existing start/tail refresh calls now
 # restore the instantaneous rate, without adding a second full projection.
 _e03_interval = {}
 super.tick(dt,actor_dt)

func end_room() -> void:
 super.end_room()
 _e03_episode = {};_e03_interval = {}
