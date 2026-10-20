extends "res://tests/ink_first_floor_enemy_views_20261004/enemy_view.gd"
## First-floor presentation successor. No source-state, collision or event mutation.
const BODY_SHADER = preload("res://yan_enemy_cartoon_20261019/body.gdshader")
const OUTLINE_SHADER = preload("res://yan_enemy_cartoon_20261019/outline.gdshader")
# Exact active siege_brood/minion/minion.glb names, confirmed in native surfaces.
const MINION_FORM_TAGS := {
 "aged_bronze.005": {"pigment":"826747","width":0.45,"form":false},
 "Brood hot vermilion.002": {"width":0.45,"form":false},
 "brood_bone_ceramic.001": {"pigment":"C7B68F","width":0.75,"form":true},
 "brood_carapace.001": {"pigment":"B78955","width":1.20,"form":true}
}
var cartoon_receipt: Dictionary = {"installed":false,"art_accepted":false}
var _cartoon_slots: Array[Dictionary] = []
var _cartoon_on := false
var _body_parent_id := 0
var _restore_errors: Array[String] = []
const BOSS_ASSET := "res://assets/arena/enemies/boss.glb"
const BOSS_ASSET_SHA := "3c71ee0275722fcf7e33f1b3821f9e09475fca8d3b2dd869e4d3e3b6e7650d3d"
const BOSS_COPPER_NODE := "ContactFit_copper knee lames and tasset spines"
const BOSS_COPPER_RESOURCE := "boss_ContactFit_front tasset bronze spine"
var _external_boss_surfaces: Array[String] = []
var _external_boss_mesh: MeshInstance3D
var _external_boss_resource: Mesh
var _external_boss_parent_id := 0
var _external_boss_skin: Skin
var _external_boss_overlay: Material
var _external_boss_override: Material
var _external_boss_skeleton: NodePath
var _boss_original_fallback := false

func configure(actor_kind: String) -> bool:
 var matched_minion_tags: Array[String] = []
 if actor_kind == "hero" or not _cartoon_slots.is_empty(): return _cartoon_deny("unsupported_actor_or_repeat_configure")
 if not super.configure(actor_kind): return false
 if get_parent() == null: return _cartoon_deny("body_parent_missing")
 _body_parent_id = get_parent().get_instance_id()
 if not _bind_existing_boss_owner():
  # Runtime import identity is not yet certified by the detached preview.
  # Keep the already configured original Boss view; never suppress the Boss.
  _boss_original_fallback = true
  import_report["cartoon_fallback_reason"] = str(cartoon_receipt.get("reason","boss_external_owner_not_bound"))
  cartoon_receipt = {"installed":false,"original_boss_fallback":true,"reason":str(cartoon_receipt.get("reason","boss_external_owner_not_bound")),"art_accepted":false}
  return true
 # Validate all ownership before replacing anything; imported meshes stay shared.
 for mesh: MeshInstance3D in meshes:
  if not _cartoon_eligible(mesh): continue
  if mesh.material_override != null:
   return _cartoon_deny("existing_mesh_override_owner")
  for index in range(mesh.mesh.get_surface_count()):
   var old: Material = mesh.get_surface_override_material(index)
   if not old is StandardMaterial3D or old.next_pass != null:
    return _cartoon_deny("unsupported_surface_or_existing_next_pass_owner")
 for mesh: MeshInstance3D in meshes:
  if not _cartoon_eligible(mesh): continue
  for index in range(mesh.mesh.get_surface_count()):
   var old: StandardMaterial3D = mesh.get_surface_override_material(index) as StandardMaterial3D
   var authored: Material = mesh.mesh.surface_get_material(index)
   var hint: String = authored.resource_name.to_lower() if authored != null else ""
   var mat := ShaderMaterial.new(); mat.shader = BODY_SHADER
   mat.set_shader_parameter("pigment",_cartoon_swatch(hint))
   mat.set_shader_parameter("has_map",old.albedo_texture != null)
   if old.albedo_texture != null: mat.set_shader_parameter("authored_map",old.albedo_texture)
   var outline := ShaderMaterial.new(); outline.shader = OUTLINE_SHADER
   outline.set_shader_parameter("width_px",1.65)
   if actor_kind == "minion" and authored != null and MINION_FORM_TAGS.has(authored.resource_name):
    matched_minion_tags.append(authored.resource_name)
    var form: Dictionary = MINION_FORM_TAGS[authored.resource_name]
    if form.has("pigment"): mat.set_shader_parameter("pigment",Color(str(form.pigment)))
    mat.set_shader_parameter("minion_form_enabled",bool(form.form))
    outline.set_shader_parameter("width_px",float(form.width))
   mat.next_pass = outline
   _cartoon_slots.append({"mesh":mesh,"mesh_id":mesh.get_instance_id(),"mesh_resource":mesh.mesh,"mesh_parent_id":mesh.get_parent().get_instance_id(),"surface":index,"original":old,"candidate":mat,"overlay":mesh.material_overlay,"mesh_override":mesh.material_override,"skin":mesh.skin,"skeleton_path":mesh.skeleton})
 if not set_cartoon_enabled(true): return _cartoon_deny("initial_surface_install_failed")
 cartoon_receipt = {"installed":true,"kind":actor_kind,"surfaces":_cartoon_slots.size(),"outline_requested_px":1.65,"skinned_mesh_reused":true,"health_ui_unchanged":true,"event_vfx_unchanged":true,"art_accepted":false,"runtime_verified":false,"preserved_external_boss_surfaces":_external_boss_surfaces.duplicate()}
 if actor_kind == "minion":
  cartoon_receipt["minion_exact_tag_form_policy"] = true
  cartoon_receipt["minion_material_tags_matched"] = matched_minion_tags
  cartoon_receipt["minion_material_match_count"] = matched_minion_tags.size()
 return true

func _cartoon_deny(reason: String) -> bool:
 cartoon_receipt = {"installed":false,"reason":reason,"art_accepted":false}
 import_report = {"status":"HOLD_cartoon_presentation","reason":reason,"kind":kind}
 return false

func _bind_existing_boss_owner() -> bool:
 if kind != "boss": return true
 if FileAccess.get_sha256(BOSS_ASSET) != BOSS_ASSET_SHA:
  cartoon_receipt["reason"] = "exact_boss_asset_changed"; return false
 var matches: Array[MeshInstance3D] = []
 for mesh: MeshInstance3D in meshes:
  if str(mesh.name) == BOSS_COPPER_NODE: matches.append(mesh)
 if matches.size() != 1:
  cartoon_receipt["reason"] = "exact_boss_copper_node_missing_or_duplicate"; return false
 var mesh: MeshInstance3D = matches[0]
 if mesh.mesh == null or mesh.mesh.resource_name != BOSS_COPPER_RESOURCE or mesh.mesh.get_surface_count() != 1 or mesh.skin == null:
  cartoon_receipt["reason"] = "exact_boss_copper_resource_changed"; return false
 _external_boss_mesh = mesh; _external_boss_resource = mesh.mesh
 _external_boss_parent_id = mesh.get_parent().get_instance_id(); _external_boss_skin = mesh.skin
 _external_boss_overlay = mesh.material_overlay; _external_boss_override = mesh.material_override; _external_boss_skeleton = mesh.skeleton
 _external_boss_surfaces.append(str(mesh.name))
 return true

func _external_boss_identity_ok() -> bool:
 if kind != "boss": return true
 return is_instance_valid(get_parent()) and get_parent().get_instance_id() == _body_parent_id and is_instance_valid(_external_boss_mesh) and str(_external_boss_mesh.name) == BOSS_COPPER_NODE and is_instance_valid(_external_boss_mesh.get_parent()) and _external_boss_mesh.get_parent().get_instance_id() == _external_boss_parent_id and _external_boss_mesh.mesh == _external_boss_resource and _external_boss_mesh.skin == _external_boss_skin and _external_boss_mesh.skeleton == _external_boss_skeleton and _external_boss_mesh.material_overlay == _external_boss_overlay and _external_boss_mesh.material_override == _external_boss_override and _external_boss_mesh.mesh.get_surface_count() == 1

func _cartoon_eligible(mesh: MeshInstance3D) -> bool:
 # Only this exact original boss mesh instance belongs to the existing art02
 # copper treatment. Never skip arbitrary foreign surface/overlay owners.
 return kind != "boss" or mesh != _external_boss_mesh

func _cartoon_swatch(hint: String) -> Color:
 if "bronze" in hint or "brass" in hint or "copper" in hint: return Color("B7A16B")
 if "bone" in hint or "ivory" in hint: return Color("DED4AD")
 if "vermilion" in hint or "ember" in hint or "terracotta" in hint or "eye" in hint: return Color("B66046")
 if "violet" in hint: return Color("8883AA")
 if "jade" in hint: return Color("73A090")
 if "ink" in hint or "charcoal" in hint or "graphite" in hint or "cloth" in hint: return Color("293B40")
 return Color("4C6661")

func apply_sample(sample: Dictionary) -> void:
 if _boss_original_fallback:
  super.apply_sample(sample)
  return
 if not ownership_report().get("owned",false):
  set_cartoon_enabled(false)
  if kind == "boss":
   # Preserve the original ready report, or the existing roster hides everyone.
   # This is an explicit art downgrade, never successful cartoon ownership.
   _boss_original_fallback = true
   cartoon_receipt = {"installed":false,"original_boss_fallback":true,"reason":"runtime_boss_binding_invalid","art_accepted":false}
   super.apply_sample(sample)
   return
  visible = false
  cartoon_receipt["reason"] = "apply_binding_invalid"
  sample_report = {"status":"HOLD_cartoon_ownership","reason":"apply_binding_invalid","kind":kind}
  return
 super.apply_sample(sample)
 if not _cartoon_on: return
 # Existing contact-derived pulse only. No new timer, event sink or damage logic.
 var hit: float = clampf(float(sample.get("hit_flash",0.0))/0.12,0.0,1.0)
 for slot: Dictionary in _cartoon_slots:
  (slot.candidate as ShaderMaterial).set_shader_parameter("hit_amount",hit)

func _slot_identity_ok(slot: Dictionary) -> bool:
 var mesh: MeshInstance3D = slot.mesh
 if not is_instance_valid(mesh) or not is_instance_valid(get_parent()): return false
 if not is_instance_valid(mesh.get_parent()): return false
 return get_parent().get_instance_id() == _body_parent_id and mesh.get_instance_id() == int(slot.mesh_id) and mesh.get_parent().get_instance_id() == int(slot.mesh_parent_id) and mesh.mesh == slot.mesh_resource and mesh.skin == slot.skin and mesh.skeleton == slot.skeleton_path

func set_cartoon_enabled(enabled: bool) -> bool:
 if _boss_original_fallback: return not enabled
 _restore_errors.clear()
 if enabled:
  # All-or-none admission; no foreign material or identity may be overwritten.
  for slot: Dictionary in _cartoon_slots:
   if not _slot_identity_ok(slot):
    _restore_errors.append("identity_changed"); return false
   var mesh: MeshInstance3D = slot.mesh
   var expected: Material = slot.candidate if _cartoon_on else slot.original
   if mesh.get_surface_override_material(int(slot.surface)) != expected or mesh.material_overlay != slot.overlay or mesh.material_override != slot.mesh_override:
    _restore_errors.append("surface_or_overlay_owner_changed"); return false
  for slot: Dictionary in _cartoon_slots:
   (slot.mesh as MeshInstance3D).set_surface_override_material(int(slot.surface),slot.candidate)
  _cartoon_on = true
  return true
 # Restore each still-owned surface independently. One foreign slot never blocks
 # cleanup of the other slots; identity-changed surfaces are left untouched.
 for slot: Dictionary in _cartoon_slots:
  if not _slot_identity_ok(slot):
   _restore_errors.append("identity_changed_skip"); continue
  var mesh: MeshInstance3D = slot.mesh
  var current: Material = mesh.get_surface_override_material(int(slot.surface))
  if current == slot.candidate:
   mesh.set_surface_override_material(int(slot.surface),slot.original)
  elif current != slot.original:
   _restore_errors.append("foreign_surface_preserved")
  if mesh.material_overlay != slot.overlay: _restore_errors.append("foreign_overlay_preserved")
  if mesh.material_override != slot.mesh_override: _restore_errors.append("foreign_mesh_override_preserved")
 _cartoon_on = false
 return _restore_errors.is_empty()

func ownership_report() -> Dictionary:
 if _boss_original_fallback:
  return {"owned":false,"restored":_restore_errors.is_empty(),"candidate_enabled":false,"slots":_cartoon_slots.size(),"original_boss_fallback":true,"restore_errors":_restore_errors.duplicate(),"reason":cartoon_receipt.get("reason","")}
 var valid: bool = not _cartoon_slots.is_empty() and _external_boss_identity_ok()
 var restored: bool = not _cartoon_slots.is_empty()
 for slot: Dictionary in _cartoon_slots:
  var identity: bool = _slot_identity_ok(slot)
  valid = valid and identity; restored = restored and identity
  if identity:
   var mesh: MeshInstance3D = slot.mesh
   var current: Material = mesh.get_surface_override_material(int(slot.surface))
   valid = valid and mesh.material_overlay == slot.overlay and mesh.material_override == slot.mesh_override and current == (slot.candidate if _cartoon_on else slot.original)
   restored = restored and mesh.material_overlay == slot.overlay and mesh.material_override == slot.mesh_override and current == slot.original
 return {"owned":valid,"restored":restored,"candidate_enabled":_cartoon_on,"slots":_cartoon_slots.size(),"errors":_restore_errors.duplicate(),"external_boss_mesh_identity":_external_boss_identity_ok(),"external_boss_surface_owner":"existing_boss_art02" if kind == "boss" else "none","hero_scope":false}

func _exit_tree() -> void:
 set_cartoon_enabled(false)
