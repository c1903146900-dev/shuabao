extends "res://tests/ink_ultimate_presentation_art_20261006/dual_v03/imported_gate01/consumer_candidate.gd"
## Candidate art only. Original GLB, imported binding, source clocks and ownership stay authoritative.
## The small shoulder-space exaggeration is sampled, not accumulated each frame.
const BrushArt_ROOT := "res://tests/ink_ultimate_brush_art_20261008/candidate01/"
const BrushArt_TIP := Vector3(.00862963, -.97367965, .00669972)
var brush_art_enabled: bool = true
var brush_art_nib_enabled: bool = true
var brush_art_report: Dictionary = {}
var _brush_art_nib: MeshInstance3D

func _ready() -> void:
 super._ready()
 _brush_art_nib = MeshInstance3D.new()
 _brush_art_nib.name = "RBrushLoadedNibArtOnly"
 var mesh := CylinderMesh.new()
 mesh.top_radius = .047
 mesh.bottom_radius = 0.0
 mesh.height = .15
 mesh.radial_segments = 8
 mesh.rings = 1
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(.025, .044, .040, 1.0)
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 mesh.material = material
 _brush_art_nib.mesh = mesh
 _brush_art_nib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _brush_art_nib.visible = false
 add_child(_brush_art_nib)

static func brush_art_envelope(u: float, start: float, crest: float, end: float) -> float:
 if u <= start or u >= end: return 0.0
 if u < crest: return smoothstep(start, crest, u)
 return 1.0 - smoothstep(crest, end, u)

func _sample(clip: String, at: float) -> Array[Transform3D]:
 var poses: Array[Transform3D] = super._sample(clip, at)
 if not brush_art_enabled or clip not in ["r1_presentation_upper", "r2_presentation_upper"] or poses.is_empty(): return poses
 var seconds: float = 1.0 if clip == "r1_presentation_upper" else 1.2
 var u: float = clampf(at / seconds, 0.0, 1.0)
 # Early lift is intentionally visible before the source's .22/.24 chest gather.
 # Opening peak follows that gather; all deltas are exactly zero at carry endpoints.
 var lift: float = brush_art_envelope(u, .015, .20, .64)
 var open: float = brush_art_envelope(u, .16, .50, .87)
 var r1: bool = clip == "r1_presentation_upper"
 var right_roll: float = 21.0 * lift + (11.0 if r1 else 17.0) * open
 var left_roll: float = -(6.0 * lift + (12.0 if r1 else 18.0) * open)
 _brush_art_rotate_shoulder(poses, "upper_arm_R", right_roll)
 _brush_art_rotate_shoulder(poses, "upper_arm_L", left_roll)
 return poses

func _brush_art_rotate_shoulder(poses: Array[Transform3D], bone: String, degrees: float) -> void:
 var index: int = skeleton.find_bone(bone)
 if index < 0 or absf(degrees) < .000001: return
 var chest: Basis = _global_pose(poses, chest_index).basis.orthonormalized()
 var global_bone: Basis = _global_pose(poses, index).basis
 # Character transverse plane: local +X right, +Y up, +Z forward. Chest carries
 # this axis through the existing facing/compensation; no camera-facing or root edit.
 var axis: Vector3 = chest.z.normalized()
 _set_global_basis(poses, index, Basis(axis, deg_to_rad(degrees)) * global_bone)

func _present_combat_q3(ink: Dictionary) -> void:
 super._present_combat_q3(ink)
 _brush_art_update_nib()

func _brush_art_update_nib() -> void:
 if not is_instance_valid(_brush_art_nib): return
 _brush_art_nib.visible = false
 brush_art_report = {"enabled":brush_art_enabled, "visible":false, "clock":"validated_actor_elapsed", "wall_clock":false, "lower_written":false, "source_written":false, "art_accepted":false}
 if not brush_art_enabled or not brush_art_nib_enabled or not bool(ultimate_report.get("visible", false)) or skeleton == null or last_rendered_pose.is_empty(): return
 var elapsed: float = float(ultimate_report.get("elapsed", 0.0))
 var seconds: float = 1.0 if str(ultimate_report.get("ability_id", "")) == "yanguizhou_r1" else 1.2
 var weight: float = brush_art_envelope(elapsed / seconds, .055, .24, .88)
 if weight <= .001: return
 var index: int = skeleton.find_bone("brush")
 if index < 0: return
 var bone: Transform3D = skeleton.global_transform * _global_pose(last_rendered_pose, index)
 # A single tapered ink-loaded nib at the true brush tip. No trail buffer, no
 # ground decal, no field-sized stroke and no particle system.
 var nib: Transform3D = bone
 nib.origin = bone * (BrushArt_TIP + Vector3.UP * .075)
 nib.basis = nib.basis.scaled(Vector3(weight, 1.0, weight))
 _brush_art_nib.global_transform = nib
 _brush_art_nib.visible = true
 brush_art_report.merge({"visible":true, "actor_elapsed":elapsed, "envelope":weight, "tip_world":bone * BrushArt_TIP, "nib_length_m":.15, "max_nib_diameter_m":.094, "particles":0, "rotation_bones":["upper_arm_R", "upper_arm_L"]}, true)
 sample_report["brush_art"] = brush_art_report.duplicate(true)

func _reset_ultimate_state() -> void:
 super._reset_ultimate_state()
 if is_instance_valid(_brush_art_nib): _brush_art_nib.visible = false
 brush_art_report.clear()
