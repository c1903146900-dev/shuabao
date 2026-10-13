extends RefCounted
const OriginalText=preload("res://tests/ink_initial_vortex_host_20261004/text_projection.gd")
## Read-only presentation, only the initial preparation state is corrected.
static func eligible(phase: String,session_status: String,dead: bool) -> bool:
 return phase == "preparation" and session_status == "preparation" and not dead
static func status(existing: String,phase: String,session_status: String,dead: bool,paused: bool=false) -> String:
 if eligible(phase,session_status,dead) and existing == "状态：遭遇结束": return OriginalText.preparation_status(paused)
 return existing
static func hint(existing: String,receipt: Dictionary,old_suffix: String,phase: String,session_status: String,dead: bool) -> String:
 if not eligible(phase,session_status,dead): return existing
 if receipt.get("accepted",false) != true or str(receipt.get("reason","")) != "developer_first_floor_bound": return existing
 if existing.ends_with(old_suffix): return existing.trim_suffix(old_suffix)+"\n初始准备完成"
 return existing
