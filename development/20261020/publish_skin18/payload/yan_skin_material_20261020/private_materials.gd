extends Node
## Test-only private material ownership. No geometry or animation processing.
const ASSET := "res://tests/ink_q3_gesture_runtime_20261004/assets/yanguizhou_q3_gestures.glb"
const ROLES := {
 "ScholarSurface_01_ink_robe": ["StandardMaterial3D_05s02", 0.28],
 "ScholarSurface_02_moon_silk": ["StandardMaterial3D_jjngf", 0.12],
 "ScholarSurface_03_mineral_lining": ["StandardMaterial3D_3e5pb", 0.20],
 "ScholarSurface_04_hair_and_wet_ink": ["StandardMaterial3D_47wl3", 0.0],
 "ScholarSurface_05_warm_porcelain": ["StandardMaterial3D_wprq5", 0.0],
 "ScholarSurface_06_old_brass": ["StandardMaterial3D_1jx1r", 0.0],
 "ScholarSurface_07_black_bamboo": ["StandardMaterial3D_3xu3h", 0.0],
 "ScholarSurface_08_inkstone": ["StandardMaterial3D_21d5a", 0.0],
 "ScholarSurface_09_ink_to_moon_cloth": ["StandardMaterial3D_0135i", 0.20]
}
var receipt: Dictionary = {"installed":false,"art_passed":false}
var _slots: Array[Dictionary] = []
var _attempted := false

func ensure(bindings: Array) -> Dictionary:
 if _attempted:
  if bool(receipt.get("installed",false)):
   for slot: Dictionary in _slots:
    if not _identity(slot) or slot.node.get_surface_override_material(0) != slot.candidate:
     restore()
     receipt["reason"] = "binding_or_material_owner_changed"
     break
  return receipt
 _attempted = true
 if bindings.size() != 9: return _deny("expected_nine_bindings")
 var seen: Array[String] = []
 var material_report: Array[Dictionary] = []
 var pending: Array[Dictionary] = []
 for binding: Dictionary in bindings:
  var node: MeshInstance3D = binding.get("node") as MeshInstance3D
  if not is_instance_valid(node) or not ROLES.has(str(node.name)) or str(node.name) in seen: return _deny("unknown_or_duplicate_skin")
  if node.mesh == null or node.mesh.get_surface_count() != 1 or node.material_override != null or node.material_overlay != null: return _deny("foreign_mesh_material_owner")
  if node.get_surface_override_material(0) != null: return _deny("foreign_surface_override")
  var original: StandardMaterial3D = node.mesh.surface_get_material(0) as StandardMaterial3D
  var role: Array = ROLES[str(node.name)]
  if original == null or original.resource_path != ASSET + "::" + str(role[0]) or original.albedo_texture == null: return _deny("exact_original_material_or_texture_missing")
  if original.next_pass != null or original.emission_enabled: return _deny("unexpected_existing_pass_or_emission")
  var candidate := original.duplicate(false) as StandardMaterial3D
  candidate.resource_local_to_scene = true
  candidate.roughness = 1.0
  candidate.metallic = 0.0
  candidate.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
  if float(role[1]) > 0.0:
   candidate.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
   var tint: Color = original.albedo_color
   candidate.albedo_color = Color(tint.r*0.84,tint.g*0.84,tint.b*0.84,tint.a)
   candidate.emission_enabled = true
   candidate.emission = Color(tint.r,tint.g,tint.b,1.0)
   candidate.emission_texture = original.albedo_texture
   candidate.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
   candidate.emission_on_uv2 = false
   candidate.emission_energy_multiplier = float(role[1])
  material_report.append({"role":str(node.name),"source_material":original.resource_path,"texture_id":original.albedo_texture.get_instance_id(),"texture_shared_unchanged":candidate.albedo_texture == original.albedo_texture,"uv1_scale_preserved":candidate.uv1_scale == original.uv1_scale,"uv1_offset_preserved":candidate.uv1_offset == original.uv1_offset,"transparency_preserved":candidate.transparency == original.transparency,"alpha_scissor_preserved":candidate.alpha_scissor_threshold == original.alpha_scissor_threshold,"cull_preserved":candidate.cull_mode == original.cull_mode,"original_metallic":original.metallic,"original_roughness":original.roughness,"original_specular":original.metallic_specular,"cloth_fill":float(role[1])})
  pending.append({"node":node,"parent":node.get_parent(),"mesh":node.mesh,"skin":node.skin,"skeleton":node.skeleton,"layers":node.layers,"original":original,"candidate":candidate})
  seen.append(str(node.name))
 # All bindings validated before the first write. Shared resources are untouched.
 _slots = pending
 for slot: Dictionary in _slots: slot.node.set_surface_override_material(0,slot.candidate)
 receipt = {"installed":true,"reason":"private_materials_installed","matched_roles":seen,"surface_count":_slots.size(),"materials":material_report,"shared_resources_written":false,"per_frame_geometry_work":false,"art_passed":false,"runtime_verified":false,"narrow_silhouette_not_fixed":true}
 return receipt

func _identity(slot: Dictionary) -> bool:
 var node: MeshInstance3D = slot.node
 return is_instance_valid(node) and node.get_parent() == slot.parent and node.mesh == slot.mesh and node.skin == slot.skin and node.skeleton == slot.skeleton and node.layers == slot.layers and node.material_override == null and node.material_overlay == null and node.mesh.get_surface_count() == 1 and node.mesh.surface_get_material(0) == slot.original

func restore() -> void:
 var errors: Array[String] = []
 for slot: Dictionary in _slots:
  if not _identity(slot):
   errors.append("identity_changed_preserved"); continue
  var current: Material = slot.node.get_surface_override_material(0)
  if current == slot.candidate: slot.node.set_surface_override_material(0,null)
  elif current != null: errors.append("foreign_override_preserved")
 receipt["installed"] = false
 receipt["restoration_complete"] = errors.is_empty()
 receipt["restore_errors"] = errors

func _deny(reason: String) -> Dictionary:
 receipt = {"installed":false,"reason":reason,"original_materials_retained":true,"art_passed":false}
 return receipt

func _exit_tree() -> void:
 restore()
