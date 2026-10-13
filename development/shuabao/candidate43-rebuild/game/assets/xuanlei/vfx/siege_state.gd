class_name SiegeStateVFX
extends Node3D
## Sustained effects follow real states, never infer protection from an animation.
const FX = preload("res://assets/xuanlei/vfx/siege_vfx.gd")
var _builder := FX.new()
var _field_art := preload("res://assets/xuanlei/vfx/e3_field_art.gd").new()
var _stacks: Array[MeshInstance3D] = []
var _charge: MeshInstance3D
var _wounds: Array[MeshInstance3D] = []
var _guard: MeshInstance3D
var _field: Node3D
var _field_anchors: Array[MeshInstance3D] = []
var _field_material: ShaderMaterial
var _field_ground_material: ShaderMaterial
var _e3_shield: Node3D
var _e3_shield_material: ShaderMaterial
var _e3_shield_age:=0.0
var _e3_shield_strength:=0.0
var _fortress: Array[MeshInstance3D] = []
var _clock := 0.0
var _guard_age := 0.0
var _field_age := 0.0
var _fortress_age := 0.0
var _pressure := 0.0
var _missing_strength := 0.0

func _visual(mesh: Mesh, at: Vector3, tint: Color, parent: Node3D = self) -> MeshInstance3D:
	var v := MeshInstance3D.new(); v.mesh=mesh; v.material_override=_builder._material(tint)
	v.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(v); v.position=at; v.visible=false
	return v

func _ready() -> void:
	for i in range(4):
		var stack:=_visual(_builder._arc_mesh(0.85,0.09,0.92,12),Vector3.UP*0.04,FX.JADE)
		stack.rotation.y=i*PI*0.5; _stacks.append(stack)
	_charge=_visual(_builder._arc_mesh(0.25,0.055,TAU,24),Vector3(0,1.92,-0.51),FX.GOLD)
	_charge.rotation.x=PI*0.5
	for i in range(3):
		var crack:=PrismMesh.new(); crack.size=Vector3(0.035,0.30,0.025)
		var wound:=_visual(crack,Vector3((i-1)*0.12,1.55+i*0.08,-0.39),Color("d8ad65"))
		wound.rotation.z=0.4 if i%2==0 else -0.45; _wounds.append(wound)
	# Frontal gate shield: visible above ground and at gameplay zoom throughout hold.
	_guard=_visual(_builder.gate_mesh(2.55,1.95,FX.JADE,true),Vector3(0,1.02,-1.25),Color.WHITE)
	_field=Node3D.new();add_child(_field);_field.visible=false
	_field_material=_field_art.material()
	_field_ground_material=_field_art.material(false,true)
	var boundary:=_visual(_field_art.etched_boundary(4.0),Vector3.UP*0.026,Color.WHITE,_field)
	boundary.material_override=_field_ground_material;boundary.visible=true
	for i in range(8):
		var a:=i*TAU/8+PI/8
		var d:=Vector3(sin(a),0,-cos(a))
		# Low chipped jade/basalt anchors sit on the floor, never hover or bob.
		var anchor:=_visual(_field_art.fractured_plate(0.77,0.35,0.17,i),d*3.80+Vector3.UP*0.012,Color.WHITE,_field)
		anchor.rotation.y=-a;anchor.material_override=_field_material;anchor.visible=true;_field_anchors.append(anchor)
		var chip:=_visual(_field_art.fractured_plate(0.27,0.18,0.066,i+3),d*3.84+d.rotated(Vector3.UP,PI/2)*0.49+Vector3.UP*0.012,Color.WHITE,_field)
		chip.rotation.y=-a+0.29;chip.material_override=_field_material;chip.visible=true
	_e3_shield=Node3D.new();add_child(_e3_shield);_e3_shield.visible=false
	_e3_shield_material=_field_art.material(true)
	for i in range(3):
		var a:=-PI*0.5+(-1+i)*0.44
		var d:=Vector3(sin(a),0,-cos(a))
		var slat:=_visual(_field_art.fractured_plate(0.39,1.08,0.067,i+6),d*1.48+Vector3.UP*1.10,Color.WHITE,_e3_shield)
		slat.rotation=Vector3(-PI*0.5,-a,0);slat.material_override=_e3_shield_material;slat.visible=true
		var etch:=_visual(_field_art.shield_inlay(),slat.position,Color.WHITE,_e3_shield)
		etch.rotation=slat.rotation;etch.material_override=_e3_shield_material;etch.visible=true
	# R1 remains a separate fortress mantle; E3 boundary stones stay ground-level.
	for i in range(3):
		var a:=(-1+i)*1.35
		var gate:=_visual(_builder.gate_mesh(1.12,1.55,FX.GOLD,true),Vector3(sin(a)*1.50,0.85,cos(a)*1.32),Color(0.78,0.93,1.0,0.66))
		gate.rotation.y=-a+PI; _fortress.append(gate)

func set_passive(kind: int, stacks: int, armed: bool, missing_health_strength: float) -> void:
	if not is_node_ready(): return
	for i in range(_stacks.size()): _stacks[i].visible=kind==0 and i<stacks
	_charge.visible=kind==1 and armed
	_missing_strength=clampf(missing_health_strength,0,1) if kind==2 else 0.0
	for wound in _wounds: wound.visible=_missing_strength>0.02

func set_guard(active: bool) -> void:
	if not is_node_ready(): return
	if active and not _guard.visible: _guard_age=0
	_guard.visible=active

func set_field(active: bool, radius: float = 4.0) -> void:
	if not is_node_ready(): return
	if active and not _field.visible: _field_age=0
	_field.visible=active
	_field.scale=Vector3(radius/4.0,1,radius/4.0)

func set_e3_shield(active: bool, strength: float = 1.0) -> void:
	# Caller must supply the actual E3-specific shield state, never field activity.
	# A retained shield can outlive the field; depletion hides the cue immediately.
	if not is_node_ready(): return
	var visible_now:=active and strength>0.0
	if visible_now and not _e3_shield.visible:_e3_shield_age=0.0
	_e3_shield_strength=clampf(strength,0.0,1.0) if visible_now else 0.0
	_e3_shield.visible=visible_now
	_e3_shield_material.set_shader_parameter("strength",_e3_shield_strength)

func set_fortress(active: bool, pressure_fraction: float = 0.0) -> void:
	if not is_node_ready(): return
	if active and not _fortress[0].visible: _fortress_age=0
	_pressure=clampf(pressure_fraction,0,1)
	for v in _fortress: v.visible=active

func _process(delta: float) -> void:
	_clock+=delta
	if is_instance_valid(_charge) and _charge.visible: _charge.rotation.z=_clock*1.4
	if is_instance_valid(_guard) and _guard.visible:
		_guard_age+=delta
		_guard.scale=Vector3.ONE*lerpf(0.8,1.0,minf(_guard_age/0.12,1))
		_guard.position.z=-1.25-0.035*sin(_clock*3.0)
	if is_instance_valid(_field) and _field.visible:
		_field_age+=delta
		var arrival:=lerpf(0.38,1.0,minf(_field_age/0.18,1.0))
		_field_material.set_shader_parameter("opacity",arrival)
		_field_ground_material.set_shader_parameter("opacity",arrival)
		_field_material.set_shader_parameter("pulse",0.25+0.15*sin(_clock*1.5))
	if is_instance_valid(_e3_shield) and _e3_shield.visible:
		_e3_shield_age+=delta
		_e3_shield_material.set_shader_parameter("opacity",lerpf(0.50,0.90,minf(_e3_shield_age/0.14,1.0)))
		_e3_shield_material.set_shader_parameter("pulse",0.5+0.5*sin(_clock*2.1))
	if not _fortress.is_empty() and _fortress[0].visible:
		_fortress_age+=delta
		for gate in _fortress:
			gate.scale.y=lerpf(0.3,1.0,minf(_fortress_age/0.20,1))*(1+_pressure*0.3)
	for wound in _wounds:
		if wound.visible:
			var material:=wound.material_override as StandardMaterial3D
			material.albedo_color.a=0.55+_missing_strength*0.35+0.06*sin(_clock*5)

func _exit_tree() -> void:
	if is_instance_valid(_builder): _builder.free()
