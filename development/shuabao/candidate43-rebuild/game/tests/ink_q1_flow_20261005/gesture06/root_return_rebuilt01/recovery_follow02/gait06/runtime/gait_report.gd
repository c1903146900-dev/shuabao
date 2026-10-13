extends RefCounted
static func capture(actor: Node3D) -> Dictionary:
 var rows: Dictionary={}
 var accepted: bool=actor.gait_ready and actor.proof.status!="HOLD"
 for base: String in actor.GAIT_CLIPS:
  var alias: String=actor.GAIT_CLIPS[base]
  var expected: String="gait06_seven_fields/"+alias
  var actual: String=str(actor.clip_names.get(alias,""))
  var animation: Animation=actor.player.get_animation(StringName(actual)) if actor.player!=null and actor.player.has_animation(StringName(actual)) else null
  var window: Dictionary=actor.key_window(animation) if animation!=null else {}
  var matched: bool=actual==expected and animation!=null and window==actor.key_windows.get(alias,{})
  accepted=accepted and matched
  rows[base]={"source_clip":alias,"actual_player_library_name":actual,"actual_window":window,"private_animation_id":animation.get_instance_id() if animation!=null else -1,"exact_consumer":matched}
 return {"schema":"gait06-seven-field-consumer-1","accepted":accepted,"asset_sha256":actor.gait_binding.get("asset_sha256",""),"clips":rows,"samples":actor.gait_base_samples.duplicate(true),"source_changed":false,"foot_lock_algorithm_changed":false,"contact_window_changed":true,"phase":actor.gait_phase_readback.duplicate(true),"art_accepted":false}
