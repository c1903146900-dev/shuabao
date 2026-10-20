extends Node3D
## Explicit unshaped display copy. Original actor remains the only animation authority.
const HeadShape = preload("res://yan_skin_copy_20261020/head_shape.gd")
var shape_enabled: bool=OS.get_cmdline_user_args().has("--test-original-skin-headshape")
var shape_evidence: Array=[]
var shape_build_usec: int=0
const OriginalBinding = preload("res://yan_front_hero_20261018/controller.gd")
var host: Node
var actor: Node3D
var rig: Skeleton3D
var source: Node
var session: Object
var player: AnimationPlayer
var actor_parent: Node
var bindings: Array = []
var receipt: Dictionary = {"ready":false,"reason":"not_attached","native_equivalence":"NOT_TESTED"}
var attached: bool = false
var terminal: bool = false
var room: String
var generation: int
var copy_evidence: Array = []

func attach_explicit(owner: Node) -> bool:
 if attached or terminal or get_parent()!=owner: return false
 var attach_started: int=Time.get_ticks_usec()
 host=owner
 actor=host.get("hero_view")
 source=host.get("sim")
 session=host.get("shop_session")
 if not is_instance_valid(actor) or not is_instance_valid(source) or not is_instance_valid(session): return _fail("missing_original_owner")
 actor_parent=actor.get_parent()
 rig=actor.get("skeleton")
 player=actor.get("player")
 if not is_instance_valid(rig) or not is_instance_valid(player): return _fail("missing_original_rig")
 room=str(source.get("room_id"))
 generation=int(source.get("encounter_generation"))
 visible=false
 for suffix: String in OriginalBinding.SKINS:
  var original: MeshInstance3D=actor.get_node_or_null(OriginalBinding.SKIN_PREFIX+suffix) as MeshInstance3D
  if original==null or original.skin==null or not original.mesh is ArrayMesh or original.get_parent()!=rig or original.get_child_count()!=0 or original.get_script()!=null: return _fail("unsupported_original_mesh:"+suffix)
  if original.get_node_or_null(original.skeleton)!=rig: return _fail("original_skeleton_path_mismatch:"+suffix)
  var copied: ArrayMesh=_copy_mesh(original.mesh)
  if copied==null: return _fail("surface_copy_not_exact:"+suffix)
  if shape_enabled:
   var source_before: Array=original.mesh.get("_surfaces")
   var shape_started: int=Time.get_ticks_usec()
   var shaped: Dictionary=HeadShape.apply(copied,original.skin,rig)
   shape_build_usec+=Time.get_ticks_usec()-shape_started
   shaped["name"]=suffix
   shape_evidence.append(shaped)
   if not shaped.get("ok",false): return _fail("head_shape_rejected:"+str(shaped.get("reason","unknown")))
   if not _same_surface_storage(source_before,original.mesh.get("_surfaces")): return _fail("source_changed_during_shape")
  # Duplicate only this leaf to preserve all GeometryInstance render settings.
  var display: MeshInstance3D=original.duplicate(0) as MeshInstance3D
  if display==null: return _fail("display_leaf_copy_failed:"+suffix)
  display.name="Copy_"+suffix
  display.mesh=copied
  display.skin=original.skin
  add_child(display)
  display.skeleton=display.get_path_to(rig)
  display.global_transform=original.global_transform
  bindings.append({"node":original,"parent":original.get_parent(),"mesh":original.mesh,"skin":original.skin,"layers":original.layers,"owned":false,"display":display,"copy_mesh":copied,"skeleton_path":original.skeleton})
  if display.get_node_or_null(display.skeleton)!=rig or display.global_transform!=original.global_transform: return _fail("display_bind_failed:"+suffix)
  var vertices: int=0
  for surface in range(copied.get_surface_count()): vertices+=copied.surface_get_array_len(surface)
  copy_evidence.append({"name":suffix,"source_node_id":original.get_instance_id(),"source_mesh_id":original.mesh.get_instance_id(),"copy_node_id":display.get_instance_id(),"copy_mesh_id":copied.get_instance_id(),"shared_skin_id":original.skin.get_instance_id(),"shared_skeleton_id":rig.get_instance_id(),"surface_count":copied.get_surface_count(),"vertex_count":vertices,"all_surface_arrays_byte_equal":not shape_enabled,"unshaped_preflight_all_arrays_byte_equal":true,"blend_arrays_byte_equal":true,"lod_storage_byte_equal":true,"all_packed_surface_storage_byte_equal":not shape_enabled,"unshaped_preflight_packed_storage_byte_equal":true,"mesh_rid_distinct":true,"materials_shared_unchanged":true,"copy_skeleton_path":str(display.skeleton)})
 if bindings.size()!=9: return _fail("original_nine_missing")
 if shape_enabled:
  var selected_total: int=0
  for row: Dictionary in shape_evidence: selected_total+=int(row.get("selected_vertices",0))
  if selected_total!=2643: return _fail("head_selection_does_not_match_offline_2643")
 attached=true
 process_priority=103
 receipt={"ready":false,"reason":"awaiting_original_frame","native_equivalence":"NOT_TESTED","source_skin_count":9,"display_skin_count":9,"shape_modified":shape_enabled,"shape_evidence":shape_evidence.duplicate(true),"shape_build_usec":shape_build_usec,"attach_build_usec":Time.get_ticks_usec()-attach_started,"materials_modified":false,"extra_animation_solver":false,"actor_external_display_branch":true,"copy_evidence":copy_evidence.duplicate(true)}
 return true

func _copy_mesh(original: ArrayMesh) -> ArrayMesh:
 # Godot 4.6.3: Resource.duplicate copies ArrayMesh's stored _surfaces.
 # This preserves packed buffers; do not decode/re-encode normals or LODs.
 var source_serialized: Variant=original.get("_surfaces")
 if not source_serialized is Array or source_serialized.size()!=original.get_surface_count(): return null
 var copy: ArrayMesh=original.duplicate(false) as ArrayMesh
 if copy==null or copy==original or not copy.get_rid().is_valid() or copy.get_rid()==original.get_rid(): return null
 if copy.get_surface_count()!=original.get_surface_count() or copy.get_blend_shape_count()!=original.get_blend_shape_count(): return null
 if copy.blend_shape_mode!=original.blend_shape_mode or copy.custom_aabb!=original.custom_aabb or copy.shadow_mesh!=original.shadow_mesh: return null
 if copy.get_aabb()!=original.get_aabb(): return null
 for i in range(original.get_blend_shape_count()):
  if copy.get_blend_shape_name(i)!=original.get_blend_shape_name(i): return null
 var copy_serialized: Variant=copy.get("_surfaces")
 if not copy_serialized is Array or not _same_surface_storage(source_serialized,copy_serialized): return null
 for i in range(original.get_surface_count()):
  if copy.surface_get_format(i)!=original.surface_get_format(i) or copy.surface_get_primitive_type(i)!=original.surface_get_primitive_type(i): return null
  if copy.surface_get_material(i)!=original.surface_get_material(i) or copy.surface_get_name(i)!=original.surface_get_name(i): return null
  if var_to_bytes(copy.surface_get_arrays(i))!=var_to_bytes(original.surface_get_arrays(i)): return null
  if var_to_bytes(copy.surface_get_blend_shape_arrays(i))!=var_to_bytes(original.surface_get_blend_shape_arrays(i)): return null
 return copy

func _same_surface_storage(original: Array, copy: Array) -> bool:
 if copy.size()!=original.size(): return false
 for i in range(original.size()):
  if not original[i] is Dictionary or not copy[i] is Dictionary: return false
  var a: Dictionary=original[i]
  var b: Dictionary=copy[i]
  if a.size()!=b.size(): return false
  for key: Variant in a:
   if not b.has(key): return false
   # Material references must be identical; all data fields must be byte-equal.
   if key=="material":
    if a[key]!=b[key]: return false
   elif var_to_bytes(a[key])!=var_to_bytes(b[key]): return false
 return true

func _same(binding: Dictionary) -> bool:
 var n: Object=binding.node
 return is_instance_valid(n) and not n.is_queued_for_deletion() and n.get_parent()==binding.parent and n.mesh==binding.mesh and n.skin==binding.skin and n.skeleton==binding.skeleton_path

func _intact() -> bool:
 if not is_instance_valid(host) or host.is_queued_for_deletion() or get_parent()!=host: return false
 if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.get_parent()!=actor_parent or host.get("hero_view")!=actor: return false
 if not is_instance_valid(source) or source.is_queued_for_deletion() or host.get("sim")!=source or host.get("shop_session")!=session: return false
 if not is_instance_valid(rig) or not is_instance_valid(player) or actor.get("skeleton")!=rig or actor.get("player")!=player: return false
 if get_world_3d()!=actor.get_world_3d() or get_viewport()!=actor.get_viewport(): return false
 for b: Dictionary in bindings:
  if not _same(b) or b.node.layers!=(0 if b.owned else b.layers): return false
  if not is_instance_valid(b.display) or b.display.is_queued_for_deletion() or b.display.get_parent()!=self or b.display.mesh!=b.copy_mesh or b.display.skin!=b.skin or b.display.get_node_or_null(b.display.skeleton)!=rig or b.display.layers!=b.layers: return false
 return bindings.size()==9

func _process(_delta: float) -> void:
 if not attached or terminal: return
 if not _intact():
  _fail("bound_identity_or_layers_changed")
  return
 if str(source.get("room_id"))!=room or int(source.get("encounter_generation"))!=generation:
  _fail("room_or_generation_changed_requires_fresh_attachment")
  return
 var proof: Variant=actor.get("proof")
 var report: Variant=actor.get("sample_report")
 if not proof is Dictionary or str(proof.get("status","HOLD"))=="HOLD" or not bool(actor.get("flow_ready")) or not report is Dictionary:
  _suspend("original_actor_not_ready")
  return
 var sampled: Variant=report.get("source_time")
 var now: Variant=source.get("hero_time")
 if not typeof(sampled) in [TYPE_INT,TYPE_FLOAT] or not typeof(now) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(sampled)) or float(sampled)!=float(now):
  _suspend("original_source_clock_not_current")
  return
 for b: Dictionary in bindings:
  if not b.node.global_transform.is_finite():
   _fail("nonfinite_original_transform")
   return
  b.display.global_transform=b.node.global_transform
  # Respect original local visibility without altering its authoritative state.
  b.display.visible=b.node.is_visible_in_tree()
  if b.display.global_transform!=b.node.global_transform:
   _fail("world_transform_copy_mismatch")
   return
 if not _intact():
  _fail("precommit_identity_changed")
  return
 for b: Dictionary in bindings:
  if not b.owned:
   b.node.layers=0
   b.owned=true
 visible=true
 receipt.merge({"ready":true,"reason":("head_shape_bound" if shape_enabled else "unshaped_copy_bound"),"source_time":sampled,"room_id":room,"generation":generation,"hidden_source_skins":9,"original_actor_id":actor.get_instance_id(),"original_skeleton_id":rig.get_instance_id(),"original_player_id":player.get_instance_id(),"world_transforms_exact_this_frame":true,"source_clock_equal_this_frame":true,"native_equivalence":"NOT_TESTED"},true)

func _restore() -> bool:
 var complete: bool=true
 for b: Dictionary in bindings:
  if not b.owned: continue
  if _same(b) and b.node.layers==0:
   b.node.layers=b.layers
   b.owned=false
  else: complete=false
 return complete

func _suspend(reason: String) -> void:
 visible=false
 var restored: bool=_restore()
 receipt.merge({"ready":false,"reason":reason,"restoration_complete":restored},true)
 if not restored: terminal=true

func _fail(reason: String) -> bool:
 _suspend(reason)
 terminal=true
 attached=false
 set_process(false)
 return false

func shutdown() -> void:
 _fail("shutdown")

func _exit_tree() -> void:
 shutdown()
