extends "res://equipment_overload_20261010/common_bridge.gd"
const SwiftRuntime = preload("runtime.gd")
func projection_base_stats()->Dictionary:
 var original: Dictionary=super.projection_base_stats()
 var owner: RefCounted=model.get_ref() if model!=null else null
 if owner==null or not owner.has_method("swift_projected_move_addition"):return original
 var addition: float=float(owner.swift_projected_move_addition(sim()))
 if is_zero_approx(addition):return original
 var derived: Dictionary=original.duplicate(true)
 derived.move_speed=float(original.move_speed)+addition
 return derived
func c03_move_speed_base()->float:
 var owner: RefCounted=model.get_ref() if model!=null else null
 if owner!=null and owner.has_method("swift_c03_move_base"):
  var approved: Dictionary=owner.swift_c03_move_base(sim())
  if approved.get("active",false):return super.c03_move_speed_base()-float(approved.contribution)
 return super.c03_move_speed_base()
func end_room()->void:
 sim().hero.cast_state.erase(SwiftRuntime.BUFF_KEY)
 super.end_room()
