extends RefCounted
# Explicitly armed bounded observation; no simulation state or per-frame I/O.
static var enabled: bool = OS.get_cmdline_user_args().has("--trial-frame-cpu-profile")
static var active: bool = false
static var closed: bool = false
static var rows: Array[Dictionary] = []
static var current_frame: int = -1
static var depths: Dictionary = {}
static var stop_reason: String = "not_armed"
const LIMIT: int = 128
const LABELS: Array[String] = ["host_process", "host_refresh", "actor_present", "actor_sample", "skills_process", "entry_process", "trial_ui_present", "legacy_effects_present", "source_step", "common_refresh", "common_context"]
static func arm() -> bool:
 if not enabled or active or closed: return false
 rows.clear(); depths.clear(); current_frame = -1
 active = true; stop_reason = "collecting"
 return true
static func begin(label: String) -> int:
 if not active or label not in LABELS: return -1
 var frame: int = Engine.get_process_frames()
 if frame != current_frame:
  if rows.size() >= LIMIT:
   active = false; closed = true; stop_reason = "frame_limit"
   return -1
  current_frame = frame
  rows.append({"process_frame":frame,"first_observed_usec":Time.get_ticks_usec(),"metrics":{}})
 var metrics: Dictionary = rows[-1]["metrics"]
 if not metrics.has(label): metrics[label] = {"calls":0,"nested_calls":0,"inclusive_usec":0,"outer_usec":0,"max_usec":0}
 var depth: int = int(depths.get(label,0))
 var metric: Dictionary = metrics[label]
 metric["calls"] += 1
 if depth > 0: metric["nested_calls"] += 1
 depths[label] = depth + 1
 return Time.get_ticks_usec()
static func end(label: String, started: int) -> void:
 if started < 0: return
 var elapsed: int = Time.get_ticks_usec() - started
 var depth: int = int(depths.get(label,1)) - 1
 depths[label] = depth
 var metric: Dictionary = rows[-1]["metrics"][label]
 metric["inclusive_usec"] += elapsed
 if depth == 0: metric["outer_usec"] += elapsed
 metric["max_usec"] = maxi(int(metric["max_usec"]),elapsed)
static func stop() -> void:
 if active:
  active = false; closed = true; stop_reason = "explicit_stop"
static func report() -> Dictionary:
 return {"enabled":enabled,"active":active,"closed":closed,"stop_reason":stop_reason,"frame_limit":LIMIT,"rows":rows.duplicate(true),"scope":"CPU wall intervals; Host refresh is inside process; actor sample inside present inside refresh; do not sum nested intervals; not GPU time"}

static func count_fixed_slice() -> void:
 if not active or rows.is_empty(): return
 if int(rows[-1].process_frame) != Engine.get_process_frames(): return
 rows[-1]["fixed_slice_calls"] = int(rows[-1].get("fixed_slice_calls",0)) + 1
