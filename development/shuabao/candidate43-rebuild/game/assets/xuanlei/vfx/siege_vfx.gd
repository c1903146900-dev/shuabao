class_name SiegeVFX
extends Node3D
## Authoritative event consumer only; simulation owns hits, targets and displacement.
## Q1 is preserved. Other impacts share its painted earth, stone and pressure assets.
const JADE := Color(0.49, 0.67, 0.64, 0.65)
const GOLD := Color(1.0, 0.69, 0.28, 0.94)
const RED := Color(1.0, 0.19, 0.055, 0.95)
const BRONZE := Color(0.44, 0.26, 0.12, 0.94)
const PALE := Color(1.0, 0.87, 0.56, 0.94)
const MAX_LIVE := 96
var _live: Array[Dictionary] = []
var _trail_clock := 0.0
var _charge_kind := ""
var _charge_count := 0
var peak_live := 0
var dropped_oldest := 0
var event_receipts: Array[Dictionary] = []
var cuicheng: Node3D
var layers: Node3D
var _tethers: Array[Dictionary] = []
var _link_mesh: ArrayMesh
var _hook_mesh: ArrayMesh

func _layers_module() -> Node3D:
	if not is_instance_valid(layers):
		layers=preload("res://assets/xuanlei/vfx/siege_layers.gd").new()
		add_child(layers)
		layers.set_process(false)
	return layers

func _q1_module() -> Node3D:
	if not is_instance_valid(cuicheng):
		cuicheng=preload("res://assets/xuanlei/vfx/cuicheng.gd").new()
		add_child(cuicheng)
		cuicheng.set_process(false) # Advanced here, respecting room pause and hitstop.
	return cuicheng

func get_live_count() -> int:
	return _live.size()+_tethers.size()*2+(cuicheng.get_live_count() if is_instance_valid(cuicheng) else 0)+(layers.get_live_count() if is_instance_valid(layers) else 0)

func _material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 0.88
	m.metallic = 0.22
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m

func _mesh(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var a: Array = []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = vertices; a[Mesh.ARRAY_COLOR] = colors; a[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var surface := SurfaceTool.new(); surface.create_from(result,0); surface.generate_normals()
	return surface.commit()

func _box(v: PackedVector3Array, c: PackedColorArray, ind: PackedInt32Array, center: Vector3, size: Vector3, tint: Color) -> void:
	var start := v.size()
	for p in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:
		v.append(center+p*size*0.5)
		c.append(tint * Color(0.72,0.72,0.72,1) if p.y<0 else tint)
	for index in [0,2,1,0,3,2,4,5,6,4,6,7,0,4,7,0,7,3,1,2,6,1,6,5,3,7,6,3,6,2,0,1,5,0,5,4]: ind.append(start+index)

func gate_mesh(width: float, height: float, tint: Color = GOLD, protective: bool = false) -> ArrayMesh:
	var v := PackedVector3Array(); var c := PackedColorArray(); var ind := PackedInt32Array()
	var body := Color(0.16,0.23,0.22,0.72) if protective else BRONZE
	for side in [-1,1]:
		_box(v,c,ind,Vector3(side*width*0.46,height*0.02,0),Vector3(width*0.12,height,0.20),body)
		_box(v,c,ind,Vector3(side*width*0.46,height*0.04,-0.115),Vector3(width*0.020,height*0.84,0.025),Color(0.78,0.84,0.73,0.78) if protective else tint)
		_box(v,c,ind,Vector3(side*width*0.46,-height*0.46,-0.04),Vector3(width*0.22,height*0.14,0.28),tint)
	_box(v,c,ind,Vector3(0,height*0.49,0),Vector3(width*1.10,height*0.17,0.24),body)
	_box(v,c,ind,Vector3(0,height*0.55,-0.13),Vector3(width*1.16,height*0.032,0.026),Color(0.78,0.84,0.73,0.78) if protective else tint)
	for x in [-0.33,0.0,0.33]:
		_box(v,c,ind,Vector3(x*width,height*0.68,0),Vector3(width*0.13,height*0.21,0.22),tint)
	if protective:
		_box(v,c,ind,Vector3(0,0,0.02),Vector3(width*0.86,height*0.88,0.018),Color(tint,0.055))
		_box(v,c,ind,Vector3(0,0,-0.03),Vector3(width*0.045,height*0.84,0.05),Color(tint,0.72))
	return _mesh(v,c,ind)

func _arc_mesh(radius: float, width: float, span: float, segments: int = 40) -> ArrayMesh:
	var v := PackedVector3Array(); var c := PackedColorArray(); var ind := PackedInt32Array()
	for i in range(segments+1):
		var a := -span*0.5+span*float(i)/segments
		var n := Vector3(sin(a),0,-cos(a))
		v.append(n*(radius-width*0.5)); v.append(n*(radius+width*0.5)); c.append(Color.WHITE); c.append(Color.WHITE)
		if i<segments:
			var j:=i*2; ind.append_array(PackedInt32Array([j,j+1,j+2,j+1,j+3,j+2]))
	return _mesh(v,c,ind)


func _add(mesh: Mesh, at: Vector3, color: Color, life: float, expand: float = 0.0, velocity: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _spawn(mesh,at,color,life,{"expand":expand,"velocity":velocity,"gravity":8.0 if velocity!=Vector3.ZERO else 0.0})

func _spawn(mesh: Mesh, at: Vector3, color: Color, life: float, options: Dictionary = {}) -> MeshInstance3D:
	if _live.size()>=MAX_LIVE:
		var oldest: Dictionary = _live.pop_front()
		if is_instance_valid(oldest.node): oldest.node.free()
		dropped_oldest+=1
	var visual := MeshInstance3D.new(); visual.mesh=mesh; visual.material_override=_material(color)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual); visual.global_position=at
	visual.rotation=options.get("rotation",Vector3.ZERO)
	visual.scale=options.get("scale",Vector3.ONE)
	var fx: Dictionary={"node":visual,"age":-float(options.get("delay",0)),"life":life,"alpha":color.a,"scale":visual.scale,"rotation":visual.rotation,"velocity":Vector3.ZERO,"gravity":0.0,"expand":0.0,"spin":Vector3.ZERO,"grow":Vector3.ZERO,"hold":0.12}
	fx.merge(options,true); _live.append(fx)
	visual.visible=fx.age>=0
	peak_live=maxi(peak_live,_live.size())
	return visual

func _yaw(direction: Vector3) -> Vector3:
	return Vector3(0,atan2(-direction.x,-direction.z),0)

func ring(at: Vector3, radius: float, color: Color = GOLD, life: float = 0.5, expansion: float = 1.5) -> void:
	_add(_arc_mesh(radius,0.075,TAU,48),at+Vector3.UP*0.04,color,life,expansion)

func slash(at: Vector3, direction: Vector3, radius: float = 1.8, span: float = 2.1, color: Color = GOLD) -> void:
	_spawn(_arc_mesh(radius,0.19,span),at+Vector3.UP*0.45,color,0.22,{"rotation":_yaw(direction),"expand":0.2})

func debris(at: Vector3, count: int = 10, strength: float = 1.0, direction: Vector3 = Vector3.ZERO) -> void:
	_layers_module().stones(at,count,strength,direction)

func _dust(at: Vector3, direction: Vector3, spread: float, count: int = 3) -> void:
	_layers_module().dust(at,direction,spread,count)

func _make_link_mesh() -> ArrayMesh:
	var vertices:=PackedVector3Array(); var colors:=PackedColorArray(); var indices:=PackedInt32Array()
	# One reusable forged oval. Alternating link rotations show the chain construction.
	for i in range(9):
		var a:=float(i)*TAU/8
		var center:=Vector3(sin(a)*0.069,0,cos(a)*0.126)
		var radial:=Vector3(sin(a),0,cos(a)).normalized()
		for j in range(5):
			var b:=float(j)*TAU/4
			vertices.append(center+radial*cos(b)*0.019+Vector3.UP*sin(b)*0.019)
			colors.append(Color(0.73,0.65,0.44) if j<2 else Color(0.34,0.29,0.20))
			if i<8 and j<4:
				var k:=i*5+j
				indices.append_array(PackedInt32Array([k,k+5,k+1,k+1,k+5,k+6]))
	return _mesh(vertices,colors,indices)

func _batch_node(mesh: Mesh, tint: Color) -> MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new()
	var batch:=MultiMesh.new(); batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.mesh=mesh; node.multimesh=batch
	node.material_override=_material(tint)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level=true # Instance transforms are authored in world space.
	add_child(node)
	node.global_transform=Transform3D.IDENTITY
	return node

func _chain_event(event: Dictionary, at: Vector3, direction: Vector3) -> void:
	var chains: Array[Dictionary]=[]
	var endpoints: Array=event.get("endpoints",[])
	var ids: Array=event.get("target_ids",[])
	# Arrays are authoritative. The fallback is only the authored empty-cast reach.
	if endpoints.is_empty():
		chains.append({"endpoint":Vector3(event.get("endpoint",at+direction*float(event.get("radius",5.0))))+Vector3.UP,
			"target_id":str(event.get("target_id",""))})
	else:
		for i in range(endpoints.size()):
			chains.append({"endpoint":Vector3(endpoints[i])+Vector3.UP,"target_id":str(ids[i]) if i<ids.size() else ""})
	_create_tether_batch(at+Vector3.UP*1.15,chains,float(event.get("duration",0.3)))
	# Contact debris stays aggregate and bounded; hooks still mark every target.
	if bool(event.get("hit",false)):
		_layers_module().dust(at,direction,0.50,2,0.72)

func chain(from: Vector3, to: Vector3, life: float = 0.32, contact: bool = true, target_id: String = "") -> void:
	_create_tether_batch(from,[{"endpoint":to,"target_id":target_id}],life)
	if contact: _layers_module().dust(to-Vector3.UP,from.direction_to(to),0.20,1,0.7)

func _create_tether_batch(origin: Vector3, chains: Array[Dictionary], duration: float) -> void:
	if _link_mesh==null: _link_mesh=_make_link_mesh()
	if _hook_mesh==null: _hook_mesh=gate_mesh(0.29,0.25,Color(0.79,0.69,0.43))
	var batch: Dictionary={"origin":origin,"chains":chains,"age":0.0,"life":maxf(0.05,duration),
		"links":_batch_node(_link_mesh,Color(1,1,1,0.86)),"hooks":_batch_node(_hook_mesh,Color(0.78,0.84,0.77,0.88))}
	_tethers.append(batch)
	_update_tether_batch(batch)

func _update_tether_batch(batch: Dictionary) -> void:
	var link_count:=0
	for tether in batch.chains:
		tether.link_count=clampi(ceili(Vector3(batch.origin).distance_to(tether.endpoint)/0.20),2,48)
		link_count+=int(tether.link_count)
	var links: MultiMesh=batch.links.multimesh
	var hooks: MultiMesh=batch.hooks.multimesh
	if links.instance_count!=link_count: links.instance_count=link_count
	if hooks.instance_count!=batch.chains.size(): hooks.instance_count=batch.chains.size()
	var index:=0; var target_index:=0
	for tether in batch.chains:
		var delta: Vector3=Vector3(tether.endpoint)-Vector3(batch.origin)
		var forward:=delta.normalized() if delta.length_squared()>0.00001 else Vector3.FORWARD
		var frame:=Basis.looking_at(forward,Vector3.RIGHT if absf(forward.y)>0.98 else Vector3.UP)
		for link in range(int(tether.link_count)):
			var t:=float(link)/maxi(1,int(tether.link_count)-1)
			# Subtle sag suggests weight; it vanishes as the two anchors approach.
			var sag:=minf(0.18,delta.length()*0.04)*sin(t*PI)
			var position_now: Vector3=Vector3(batch.origin)+delta*t-Vector3.UP*sag
			links.set_instance_transform(index,Transform3D(frame*Basis(Vector3.FORWARD,PI*0.5 if link%2 else 0.0),position_now))
			index+=1
		tether.hook_transform=Transform3D(frame,Vector3(tether.endpoint))
		hooks.set_instance_transform(target_index,tether.hook_transform)
		target_index+=1

func _process_tethers(delta: float) -> void:
	for i in range(_tethers.size()-1,-1,-1):
		var batch: Dictionary=_tethers[i]
		batch.age+=maxf(0.0,delta)
		if float(batch.age)>=float(batch.life):
			batch.links.free(); batch.hooks.free(); _tethers.remove_at(i); continue
		var opacity:=1.0-smoothstep(0.68,1.0,float(batch.age)/float(batch.life))
		for node in [batch.links,batch.hooks]:
			var material: StandardMaterial3D=node.material_override
			material.albedo_color.a=0.86*opacity

func _wide_sweep(at: Vector3, direction: Vector3, radius: float, angle_degrees: float = 240.0) -> void:
	_layers_module().sweep(at,direction,radius,angle_degrees)

func _charge_stamp(at: Vector3, direction: Vector3, ultimate: bool, count: int = 1) -> void:
	_layers_module().charge_scrape(at,direction,ultimate,count)

func _sync_tethers(at: Vector3, targets: Array) -> void:
	if _tethers.is_empty(): return
	var by_id: Dictionary = {}
	for target in targets:
		by_id[str(target.get("actor_id",""))] = Vector3(target.position)+Vector3.UP
	for batch in _tethers:
		batch.origin=at+Vector3.UP*1.15
		for tether in batch.chains:
			if by_id.has(tether.target_id): tether.endpoint=by_id[tether.target_id]
		_update_tether_batch(batch)

func sync_charge(at: Vector3, facing: Vector3, states: Dictionary, dt: float, targets: Array = []) -> void:
	if is_instance_valid(cuicheng):cuicheng.follow_windup(at)
	_sync_tethers(at,targets)
	var kind:="r2" if states.has("r2_charge") else "e2" if states.has("e2") else ""
	if kind.is_empty(): _trail_clock=0; _charge_kind=""; return
	var state: Dictionary=states.get("r2_charge",states.get("e2",{}))
	if float(state.get("windup",0))>0: return
	var direction: Vector3=state.get("direction",facing)
	if kind!=_charge_kind: _trail_clock=0.08; _charge_kind=kind
	_trail_clock+=maxf(0,dt)
	if _trail_clock>=0.075:
		_trail_clock=0
		_charge_stamp(at,direction,kind=="r2",_charge_count)

func _fortress_release(at: Vector3, radius: float) -> void:
	_layers_module().radial_release(at,radius,true)

func _final_fracture(at: Vector3, radius: float, direction: Vector3 = Vector3.FORWARD) -> void:
	_layers_module().radial_release(at,radius,false,direction)

func combat_event(event: Dictionary, fallback_position: Vector3 = Vector3.ZERO, fallback_direction: Vector3 = Vector3.FORWARD) -> void:
	var at: Vector3=event.get("position",fallback_position)
	var direction: Vector3=event.get("direction",fallback_direction)
	var before:=get_live_count()
	match str(event.get("kind","")):
		"q1_windup": _q1_module().windup(at,direction,float(event.get("animation",{}).get("contact_after",0.26)))
		"q1", "q1_echo": _q1_module().impact(at,direction,float(event.get("radius",4.2)))
		"q2_chain": _chain_event(event,at,direction)
		"q3": _wide_sweep(at,direction,float(event.get("radius",4.5)),float(event.get("angle",240.0)))
		"e1_release": _layers_module().rectangle(at,direction,float(event.get("length",event.get("radius",3.0))),float(event.get("width",2.8)))
		"e2_charge_started": _charge_stamp(at,direction,false)
		"e2_release", "e2_wall":
			# Carried-target throw, not a circular area attack.
			_spawn(gate_mesh(1.6,0.75,GOLD),at+direction*0.8+Vector3.UP*0.5,Color.WHITE,0.22,{"rotation":_yaw(direction),"velocity":direction*2.0})
			debris(at+direction*1.1,7,0.9,direction); _dust(at+direction*0.8,direction,0.7)
		"e3_aura_started": _layers_module().field_start(at,float(event.get("radius",4.0)))
		"r1_fortress_started":
			for i in range(4):
				var d:=Vector3.FORWARD.rotated(Vector3.UP,i*PI*0.5)
				_spawn(gate_mesh(1.25,1.25,JADE,true),at+d*1.5+Vector3.UP*0.6,Color.WHITE,0.5,{"rotation":_yaw(d),"scale":Vector3(0.8,0.25,1),"grow":Vector3(0.2,0.75,0)})
		"r1_release": _fortress_release(at,float(event.get("radius",6.0)))
		"r2_charge_started":
			_charge_count=clampi(int(event.get("charge",1)),1,4)
			_spawn(gate_mesh(2.25,0.75,GOLD),at+direction*1.0+Vector3.UP*0.6,Color.WHITE,0.25,{"rotation":_yaw(direction),"velocity":direction*3.5})
			_charge_stamp(at,direction,true,_charge_count)
		"r2_wall": debris(at+direction,9,1.1,direction); _dust(at,direction,1.0)
		"r2_finish": _final_fracture(at,float(event.get("radius",5.0)),direction)
		"chain_landing": _dust(at,direction,0.8)
		"encounter_started": clear_transients()
	if get_live_count()>before:
		event_receipts.append({"kind":event.kind,"sequence":event.get("sequence",-1),"nodes":get_live_count()-before,"position":at,"direction":direction,"radius":event.get("radius",0),"angle":event.get("angle",0),"length":event.get("length",0),"width":event.get("width",0),"targets":event.get("target_ids",[]).size()})
		if event_receipts.size()>64: event_receipts.pop_front()

func burst(event: StringName, at: Vector3, direction: Vector3 = Vector3.FORWARD, strength: float = 1.0) -> void:
	# Compatibility for isolated previews; live room uses authoritative combat_event.
	var names:={"e2":"e2_charge_started","e3":"e3_aura_started","r1_start":"r1_fortress_started","r1_end":"r1_release","r2_charge":"r2_charge_started","r2_end":"r2_finish"}
	if event==&"dash": _charge_stamp(at,direction,false)
	elif event==&"hit": debris(at,4,strength*0.4)
	elif str(event).begins_with("attack_"): return # Rejected legacy arc; dedicated socket-sampled module owns attacks.
	else: combat_event({"kind":names.get(str(event),str(event)),"position":at,"direction":direction,"endpoint":at+direction*5.0})

func clear_transients() -> void:
	if is_instance_valid(cuicheng): cuicheng.clear_transients()
	if is_instance_valid(layers): layers.clear_transients()
	for batch in _tethers:
		batch.links.free(); batch.hooks.free()
	_tethers.clear()
	for fx in _live:
		if is_instance_valid(fx.node): fx.node.queue_free()
	_live.clear(); _charge_kind=""; _trail_clock=0

func _process(delta: float) -> void:
	if is_instance_valid(cuicheng): cuicheng._process(delta)
	if is_instance_valid(layers): layers._process(delta)
	_process_tethers(delta)
	for i in range(_live.size()-1,-1,-1):
		var fx: Dictionary=_live[i]; var node: MeshInstance3D=fx.node
		fx.age=float(fx.age)+delta
		if fx.age<0: continue
		var t:=float(fx.age)/float(fx.life)
		if t>=1 or not is_instance_valid(node):
			if is_instance_valid(node): node.queue_free()
			_live.remove_at(i); continue
		node.visible=true
		var eased:=1.0-pow(1.0-minf(t*2.8,1.0),3)
		node.scale=(Vector3(fx.scale)+Vector3(fx.grow)*eased)*(1.0+float(fx.expand)*float(fx.age))
		node.rotation=Vector3(fx.rotation)+Vector3(fx.spin)*float(fx.age)
		if fx.has("orbit_center"):
			var sweep:=lerpf(-1.08,1.08,minf(float(fx.age)/0.14,1.0))
			var radial:=Vector3(fx.orbit_direction).rotated(Vector3.UP,sweep)
			node.global_position=Vector3(fx.orbit_center)+radial*float(fx.orbit_radius)
			node.rotation=_yaw(radial)+Vector3(0,PI/2,0)
		var velocity: Vector3=fx.velocity
		node.position+=velocity*delta; velocity.y-=float(fx.gravity)*delta; fx.velocity=velocity
		var material:=node.material_override as StandardMaterial3D
		var tint:=material.albedo_color
		tint.a=float(fx.alpha)*(1.0-clampf((t-float(fx.hold))/(1.0-float(fx.hold)),0,1))
		material.albedo_color=tint
