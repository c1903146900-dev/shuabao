extends Node3D
## Partial front combat sample. All authoritative objects remain owned by original Host.
const Capture = preload("capture.gd")
const Mapper = preload("mapper.gd")
const Renderer = preload("renderer.gd")
const SKIN_PREFIX: String = "yanguizhou_q3_gestures/Yanguizhou_Scholar/Skeleton3D/"
const SKINS: Array[String] = ["ScholarSurface_01_ink_robe","ScholarSurface_02_moon_silk","ScholarSurface_03_mineral_lining","ScholarSurface_04_hair_and_wet_ink","ScholarSurface_05_warm_porcelain","ScholarSurface_06_old_brass","ScholarSurface_07_black_bamboo","ScholarSurface_08_inkstone","ScholarSurface_09_ink_to_moon_cloth"]
var capture = Capture.new()
var mapper = Mapper.new()
var renderer = Renderer.new()
var host: Node
var source: Node
var actor: Node3D
var camera: Camera3D
var actor_parent: Node
var stage: Node3D
var skins: Array = []
var attached: bool = false
var fatal: String = ""
var receipt: Dictionary = {}

func attach_explicit(owner: Node, asset_paths: Dictionary, height: float = 2.181) -> bool:
 if attached or not is_instance_valid(owner) or owner.is_queued_for_deletion() or get_parent()!=owner: return false
 host=owner
 source=host.get("sim")
 actor=host.get("hero_view")
 stage=host.get("stage")
 if not is_instance_valid(stage): return false
 camera=stage.get("camera")
 if not is_instance_valid(source) or not is_instance_valid(actor) or not is_instance_valid(camera): return false
 if bool(host.get("_mainprep_required")) or bool(host.get("_mainprep_pending")): return false
 actor_parent=actor.get_parent()
 for suffix: String in SKINS:
  var node: Node = actor.get_node_or_null(SKIN_PREFIX+suffix)
  if not node is MeshInstance3D or node.is_queued_for_deletion() or node.mesh==null or node.skin==null or node.get_parent()!=actor.get("skeleton"): return false
  skins.append({"node":node,"parent":node.get_parent(),"mesh":node.mesh,"skin":node.skin,"layers":node.layers,"owned":false})
 add_child(renderer)
 if not renderer.initialize(asset_paths,height) or not capture.bind_explicit(source):
  renderer.queue_free()
  capture.close()
  return false
 process_priority=102
 attached=true
 return true

func _intact() -> bool:
 if not is_instance_valid(host) or host.is_queued_for_deletion() or get_parent()!=host: return false
 if not is_instance_valid(actor) or actor.is_queued_for_deletion() or host.get("hero_view")!=actor or actor.get_parent()!=actor_parent: return false
 if host.get("sim")!=source or not is_instance_valid(source) or source.is_queued_for_deletion(): return false
 if host.get("stage")!=stage or not is_instance_valid(stage) or stage.is_queued_for_deletion() or stage.get("camera")!=camera: return false
 if not is_instance_valid(camera) or camera.is_queued_for_deletion() or camera.get_viewport()!=actor.get_viewport(): return false
 if not is_instance_valid(renderer) or renderer.get_parent()!=self: return false
 if camera.get_world_3d()!=actor.get_world_3d() or renderer.get_world_3d()!=actor.get_world_3d(): return false
 if camera.cull_mask & 1 == 0: return false
 for binding: Dictionary in skins:
  if not _same_skin(binding): return false
  if binding.node.layers != (0 if binding.owned else binding.layers): return false
 return true

func _same_skin(binding: Dictionary) -> bool:
 var node: Object = binding.node
 return is_instance_valid(node) and not node.is_queued_for_deletion() and node.get_parent()==binding.parent and node.mesh==binding.mesh and node.skin==binding.skin

func _restore() -> bool:
 var complete: bool = true
 for binding: Dictionary in skins:
  if not binding.owned: continue
  if _same_skin(binding) and binding.node.layers==0:
   binding.node.layers=binding.layers
   binding.owned=false
  else: complete=false
 return complete

func fallback(reason: String) -> void:
 renderer.hide_display()
 var restored: bool = _restore()
 receipt={"accepted":false,"reason":reason,"restoration_complete":restored}
 if not restored and fatal.is_empty(): fatal="skin_restoration_ownership_lost"

func _process(_delta: float) -> void:
 if not attached or not fatal.is_empty(): return
 if not _intact():
  fatal="bound_display_identity_changed"
  fallback(fatal)
  return
 var frame: Dictionary = capture.read_frame()
 var report: Variant = actor.get("sample_report")
 var windows: Variant = actor.get("key_windows")
 if not report is Dictionary or not windows is Dictionary:
  fatal="original_actor_metadata_unavailable"
  fallback(fatal)
  return
 var plan: Dictionary = mapper.evaluate(frame,report,windows,camera.global_basis.z)
 if not plan.get("accepted",false):
  if plan.has("fault"): fatal=str(plan.fault)
  fallback(str(plan.get("fault",plan.get("reason","uncovered"))))
  return
 var meshes: Dictionary = renderer.prepare(plan)
 if meshes.is_empty() or not _intact() or not renderer.commit(meshes,actor.global_position,camera):
  fatal="mesh_preflight_or_commit_failed"
  fallback(fatal)
  return
 for binding: Dictionary in skins:
  if not binding.owned:
   binding.node.layers=0
   binding.owned=true
 renderer.visible=true
 receipt=plan.duplicate(true)
 receipt["renderer"]=renderer.receipt.duplicate(true)
 receipt["hidden_skin_count"]=skins.size()

func shutdown() -> void:
 if is_instance_valid(renderer): renderer.hide_display()
 var restored: bool = _restore()
 capture.close()
 attached=false
 receipt={"accepted":false,"reason":"shutdown","restoration_complete":restored}

func _exit_tree() -> void:
 shutdown()
