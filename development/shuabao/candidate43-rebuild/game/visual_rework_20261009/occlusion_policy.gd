extends RefCounted
## Visual-only proposal. Caller supplies camera-space visibility observations.
## Never modifies actor collisions, position, targetability, health or damage.
static func target_visual_policy(visible_target_id:String,behind_beacon:bool,is_hostile:bool,has_danger_cue:bool)->Dictionary:
 var show_outline=behind_beacon and is_hostile and not visible_target_id.is_empty()
 return {"target_id":visible_target_id,"show_occluded_outline":show_outline,"danger_cue_top_layer":behind_beacon and has_danger_cue,"beacon_global_alpha":1.0,"gameplay_mutation":false,"implemented_in_host":false}
