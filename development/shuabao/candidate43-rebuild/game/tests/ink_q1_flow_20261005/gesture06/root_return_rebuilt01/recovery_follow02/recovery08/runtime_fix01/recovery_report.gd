extends RefCounted
static func capture(actor: Node3D) -> Dictionary:
 var alias: String="q1_release_upper"
 var actual: String=str(actor.clip_names.get(alias,""))
 var animation: Animation=actor.player.get_animation(StringName(actual)) if actor.player!=null and actor.player.has_animation(StringName(actual)) else null
 var window: Dictionary=actor.key_window(animation) if animation!=null else {}
 var exact: bool=actual=="q1_recovery08_rotation_only/q1_recovery08_release_upper" and animation!=null and window==actor.key_windows.get(alias,{})
 var retained: Dictionary={}
 for key: String in ["q1_draw_upper","q1_hold_upper","brush_carry_upper"]:
  var expected: String="q1_carry_rotation_only/"+str(actor.CARRY_ALIASES[key])
  var unchanged: bool=str(actor.clip_names.get(key,""))==expected
  exact=exact and unchanged
  retained[key]={"actual_library_name":str(actor.clip_names.get(key,"")),"unchanged":unchanged}
 return {"schema":"recovery08-release-consumer-1","accepted":actor.recovery_ready and actor.proof.status!="HOLD" and exact,"asset_sha256":actor.recovery_binding.get("asset_sha256",""),"actual_release_library_name":actual,"actual_window":window,"private_animation_id":animation.get_instance_id() if animation!=null else -1,"retained_carry_aliases":retained,"active_alias":actor.active_upper,"actual_presented_time":actor.sample_report.get("upper_time",0.0),"complete_release_seconds":.60,"gait_consumer":actor.GaitReport.capture(actor).accepted,"source_changed":false,"lower_changed":false,"art_accepted":false}
