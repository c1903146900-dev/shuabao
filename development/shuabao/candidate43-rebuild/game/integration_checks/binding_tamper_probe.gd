extends SceneTree
const Sim=preload("res://tests/ink_river_hexes_20261006/ordinary01/sim.gd")
const Current=preload("res://visual_rework_20261009/binding/live_binding.gd")
var failures=0
func _initialize()->void:
 var sim=Sim.new()
 var paths=["res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd","res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd","res://tests/ink_river_hexes_20261006/frontdoor01/navigation_install.gd","res://tests/ink_river_hexes_20261006/frontdoor01/host.gd","res://visual_rework_20261009/input/q1_free_curve_sampler.gd","res://visual_rework_20261009/views/q2_water.gdshader","res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd"]
 for path in paths:
  var original=FileAccess.get_file_as_bytes(path)
  var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(original);f.store_string("\n# integrity probe\n");f.close()
  var denied=Current.read_capabilities(sim,true)
  f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(original);f.close()
  var restored=Current.read_capabilities(sim,true)
  var ok=not denied.get("accepted",true) and restored.get("accepted",false)
  if not ok:failures+=1
  print("TAMPER_REJECT_RESTORE ",path," ",ok," ",denied.get("reason",""))
 sim.free();print("TAMPER_FAILURES=",failures);quit(1 if failures else 0)
