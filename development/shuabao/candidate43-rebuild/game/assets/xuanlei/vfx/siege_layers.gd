class_name SiegeLayersVFX
extends "res://assets/xuanlei/vfx/cuicheng.gd"
## Shared Q1 paint vocabulary, separate authored shapes and lifetime budget.
## No approved Cuicheng assets, contact timing, or gameplay rules are changed.

const PRESSURE_GRADE := preload("res://assets/xuanlei/vfx/siege_pressure.gdshader")
const EARTH := Color(0.94, 0.88, 0.73, 0.85)
const STEEL := Color(0.77, 0.91, 0.87, 0.82)
const AMBER := Color(0.93, 0.72, 0.40, 0.63)
var footprints: Array[Dictionary] = []

func _record(shape: String, dimensions: Dictionary) -> void:
	var receipt := {"shape": shape}
	receipt.merge(dimensions)
	footprints.append(receipt)
	if footprints.size() > 32: footprints.pop_front()

func _pressure_paint(tint: Color) -> ShaderMaterial:
	var material:=_paint(PRESSURE,false,tint)
	material.shader=PRESSURE_GRADE
	return material

func _sector_mesh(radius: float, angle: float, raised: bool = true, inner: float = 0.12, planar_uv: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var uvs := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array()
	var segments := maxi(24, ceili(rad_to_deg(angle) / 5.0))
	const DEPTH := 6
	for i in range(segments + 1):
		var u := float(i) / segments
		var a := (u - 0.5) * angle
		var side_fade := 1.0 if angle >= TAU - 0.001 else pow(sin(PI * u), 0.35)
		for j in range(DEPTH + 1):
			var t := float(j) / DEPTH
			var tooth := 1.0 - (0.027 * absf(sin(i * 1.71)) if raised else 0.0)
			var r := radius * lerpf(inner, tooth, t)
			var h := sin(t * PI) * (0.54 + 0.24 * sin(u * 29.0 + t * 2.0)) * side_fade if raised else 0.0
			vertices.append(Vector3(sin(a) * r, h, -cos(a) * r))
			normals.append(Vector3.UP)
			uvs.append(Vector2(sin(a)*r/radius*0.5+0.5,-cos(a)*r/radius*0.5+0.5) if planar_uv else Vector2(u,0.17+(1.0-t)*0.83))
			var torn:=0.33+0.67*smoothstep(0.12,0.63,absf(sin(i*0.79)+0.24*sin(i*2.10))) if raised else 1.0
			colors.append(Color(1, 1, 1, side_fade * torn * (0.65 + 0.35 * sin(t * PI))))
			if i < segments and j < DEPTH:
				var k := i * (DEPTH + 1) + j
				indices.append_array(PackedInt32Array([k,k+DEPTH+1,k+1,k+1,k+DEPTH+1,k+DEPTH+2]))
	return _array_mesh(vertices,normals,uvs,colors,indices)

func _rectangle_mesh(length: float, width: float, raised: bool) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var uvs := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array()
	const ACROSS := 14
	const DEPTH := 12
	for i in range(ACROSS + 1):
		var u := float(i) / ACROSS
		for j in range(DEPTH + 1):
			var t := float(j) / DEPTH
			var h := sin(t * PI) * (0.55 + 0.19 * sin(u * 19.0)) if raised else 0.0
			vertices.append(Vector3((u - 0.5) * width, h, -t * length))
			normals.append(Vector3.UP); uvs.append(Vector2(u,0.17+(1.0-t)*0.83 if raised else 1.0-t))
			colors.append(Color(1,1,1,0.55+0.45*pow(sin(PI*u),0.35)))
			if i < ACROSS and j < DEPTH:
				var k := i * (DEPTH + 1) + j
				indices.append_array(PackedInt32Array([k,k+DEPTH+1,k+1,k+1,k+DEPTH+1,k+DEPTH+2]))
	return _array_mesh(vertices,normals,uvs,colors,indices)

func dust(at: Vector3, direction: Vector3, width: float = 1.0, count: int = 3, force: float = 1.0) -> void:
	_ensure_meshes()
	var frame := _frame(direction)
	for i in range(mini(count,5)):
		var x := (float(i) - float(count-1)*0.5) * width
		var position_local := Vector3(x,0.17,-0.11 * (i%2))
		var material := _paint(DUST[i%3],false,Color(0.80,0.77,0.67,0.45))
		material.set_shader_parameter("erosion_offset",Vector2(i*0.21,i*-0.13))
		_spawn(_quad,material,at+frame*position_local,frame,0.41+(i%2)*0.08,
			{"delay":0.022*(i%2),"velocity":frame*Vector3(x*0.32,0.19,-0.72)*force,
			"scale_from":Vector3(0.80,0.51,1),"scale_to":Vector3(1.55,0.78,1)*Vector3(force,force,1),
			"billboard":true,"roll":(i-1)*0.11,"fade_in":0.035,"fade_start":0.25,"erosion_start":0.25})

func stones(at: Vector3, count: int, strength: float, direction: Vector3 = Vector3.ZERO) -> void:
	_ensure_meshes()
	for i in range(mini(count,8)):
		var a := i*2.39996
		var speed := Vector3(sin(a)*1.5,2.2+(i%3)*0.38,cos(a)*1.5)*strength + direction*strength*1.4
		var size := Vector3(0.24+(i%3)*0.065,0.13,0.32+(i%2)*0.10)*maxf(0.65,strength)
		_spawn(_rocks[i%6],_stone_paint(),at+Vector3.UP*0.14,Basis.from_euler(Vector3(a*0.17,a,0.21)),0.64+(i%3)*0.07,
			{"velocity":speed,"gravity":15.0,"scale_from":size,"spin":Vector3(1.8,a*0.4,0.8),
			"stone":true,"ground_y":at.y+0.045,"fade_in":0.0,"fade_start":0.64})

func _surface(tint:Color=Color.WHITE, glow:float=0.0)->ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=preload("res://assets/xuanlei/vfx/siege_surface.gdshader")
	m.set_shader_parameter("stone_texture",BASALT);m.set_shader_parameter("tint",tint)
	m.set_shader_parameter("opacity",1.0);m.set_shader_parameter("emission_strength",glow)
	return m

func _fractures(radius:float,span:float,count:int,width:float=0.070,rot:float=0.0)->ArrayMesh:
	# Individual torn seams, never a filled sector or a ring. Endpoints preserve the hit extent.
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	for i in range(count):
		var a:=rot+lerpf(-span*.5,span*.5,float(i)/maxi(1,count-1))
		if i>0 and i<count-1:a+=sin(i*2.93)*.16
		var d:=Vector3(sin(a),0,-cos(a));var side:=Vector3(-d.z,0,d.x)
		var start_radius:=.68+radius*.22*float((i*3)%7)/7.0
		var prior:=d*start_radius
		for j in range(1,6):
			var t:=float(j)/5.0
			var p:=d*lerpf(start_radius,radius,t)
			if j<5:p+=side*(sin(i*3.1+j*1.7)*.39)*(1.0-t*.3)
			var w:=width*lerpf(1.7,.17,t)*(0.7+0.3*absf(sin(i*2.7+j)))
			if (j==2 and i%3==0) or (j==4 and i%3==1):
				prior=p;continue
			var q:=v.size()
			for point in [prior-side*w,prior+side*w,p-side*w*.63,p+side*w*.63]:
				v.append(point);n.append(Vector3.UP);uv.append(Vector2(point.x,point.z)*.8);c.append(Color(.61,.54,.44,1))
			ix.append_array(PackedInt32Array([q,q+1,q+2,q+1,q+3,q+2]));prior=p
			if j==3 and i%2==0:
				var end:=p+side*.35+d*.53;var k:=v.size()
				for point in [p-side*w*.65,p+side*w*.65,end]:
					v.append(point);n.append(Vector3.UP);uv.append(Vector2(point.x,point.z));c.append(Color(.54,.47,.37,1))
				ix.append_array(PackedInt32Array([k,k+1,k+2]))
	for index in range(v.size()):
		var point:Vector3=v[index]
		var length_xz:=Vector2(point.x,point.z).length()
		if length_xz>radius:point*=radius/length_xz
		if span<TAU-.001:
			var angle_point:=atan2(point.x,-point.z)
			var bounded:=clampf(angle_point,rot-span*.5,rot+span*.5)
			if not is_equal_approx(angle_point,bounded):point=Vector3(sin(bounded),0,-cos(bounded))*Vector2(point.x,point.z).length()
		v[index]=point
	return _array_mesh(v,n,uv,c,ix)

func _ribbon(radius:float,a0:float,a1:float,width:float,height:float)->ArrayMesh:
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	for i in range(17):
		var t:=i/16.0;var a:=lerpf(a0,a1,t);var d:=Vector3(sin(a),0,-cos(a))
		var taper:=pow(sin(PI*t),.75);var rr:=radius*(1.0+.017*sin(t*22))
		v.append(d*(rr-width*taper)+Vector3.UP*(height+sin(t*PI)*.09))
		v.append(d*rr+Vector3.UP*height)
		for k in range(2):n.append(Vector3.UP);uv.append(Vector2(t,.22 if k==0 else .54))
		c.append(Color(.58,.37,.16,taper*.16));c.append(Color(1,.88,.62,taper*.9))
		if i<16:
			var q:=i*2;ix.append_array(PackedInt32Array([q,q+2,q+1,q+1,q+2,q+3]))
	return _array_mesh(v,n,uv,c,ix)

func _scour(at:Vector3,direction:Vector3,size:Vector2,life:float=.85,delay:float=0.0)->void:
	_spawn(_ground,_paint(SCAR,false,Color(.75,.70,.58,.67)),at+Vector3.UP*.034,_frame(direction),life,
		{"scale_from":Vector3(size.x,1,size.y),"delay":delay,"fade_in":.015,"fade_start":.57,"erosion_start":.52})

func _low_dust(at:Vector3,direction:Vector3,variant:int,size:float=1.0,delay:float=0.0)->void:
	var material:=_paint(DUST[variant%3],false,Color(.81,.75,.63,.65))
	material.set_shader_parameter("erosion_offset",Vector2(.13*variant,.31*variant))
	_spawn(_quad,material,at+Vector3.UP*.15,_frame(direction),.43+.045*(variant%3),
		{"scale_from":Vector3(.76,.38,1)*Vector3(size,size,1),"scale_to":Vector3(1.83,.81,1)*Vector3(size,size,1),
		"velocity":direction*(.7+.23*(variant%2))+Vector3.UP*.17,"billboard":true,"roll":-.08+.075*(variant%3),
		"delay":delay,"grow_time":.24,"fade_in":.025,"fade_start":.25,"erosion_start":.28})

func _plate(at:Vector3,direction:Vector3,index:int,scale_value:Vector3,up:float,delay:float=0.0)->void:
	_spawn(_rocks[index%6],_stone_paint(),at+Vector3.UP*.10,_frame(direction)*Basis.from_euler(Vector3(.09,.41*index,-.15)),.69+.05*(index%3),
		{"scale_from":scale_value,"velocity":direction*(.63+.14*(index%3))+Vector3.UP*up,"gravity":14.0,
		"spin":Vector3(.73,(-.6 if index%2==0 else .6),.35),"stone":true,"ground_y":at.y+.05,
		"delay":delay,"fade_in":.0,"fade_start":.74})

func sweep(at: Vector3, direction: Vector3, radius: float, angle_degrees: float) -> void:
	_ensure_meshes()
	var angle:=deg_to_rad(clampf(angle_degrees,1,360));var frame:=_frame(direction)
	_record("sector",{"radius":radius,"angle":angle_degrees,"direction":direction,"position":at,"style":"asymmetric_gate_scour"})
	# Ground cuts establish extent, while airborne mass stays low and intermittent.
	_spawn(_fractures(radius,angle,9,.041),_surface(Color(.60,.57,.51,.70)),at+Vector3.UP*.034,frame,.82,
		{"fade_in":.012,"fade_start":.53,"erosion_start":.5})
	var offsets:=[-.46,-.30,-.095,.18,.41]
	for i in range(offsets.size()):
		var a:float=offsets[i]*angle;var d:=direction.rotated(Vector3.UP,-a)
		var r:float=radius*([.60,.73,.53,.72,.63][i])
		_scour(at+d*r,d.rotated(Vector3.UP,PI*.5),Vector2(1.1+.12*(i%2),1.52),.78,.018*i)
		_plate(at+d*r,d,i,Vector3(.55+.13*(i%3),.12,.69+.09*(i%2)),1.2+.22*(i%3),.017*i)
		_low_dust(at+d*(r+.25),d,i,.9+.13*(i%2),.028*i)
	# Three short forged pressure traces travel across the gate's horizontal sweep.
	# No single translucent surface occupies the whole 240-degree hit area.
	for i in range(3):
		var a0:float=(-.44+.29*i)*angle;var a1:float=a0+angle*.19
		_spawn(_ribbon(radius*(.59+.07*(i%2)),a0,a1,.17+.03*i,.40+.055*i),_surface(Color(1.12,.99,.73,.91),1.0),at,frame,.21,
			{"delay":.024*i,"fade_in":.009,"fade_start":.20,"erosion_start":.2})

func _extruded(v:PackedVector3Array,n:PackedVector3Array,uv:PackedVector2Array,c:PackedColorArray,ix:PackedInt32Array,outline:PackedVector2Array,depth:float,tint:Color)->void:
	var center:=Vector2.ZERO
	for p in outline:center+=p
	center/=outline.size()
	for i in range(outline.size()):
		var j:=(i+1)%outline.size();var a:Vector2=outline[i];var b:Vector2=outline[j]
		var ai:=center+(a-center)*.84;var bi:=center+(b-center)*.84
		var af:=Vector3(ai.x,ai.y,-depth*.5);var bf:=Vector3(bi.x,bi.y,-depth*.5)
		var ao:=Vector3(a.x,a.y,-depth*.32);var bo:=Vector3(b.x,b.y,-depth*.32)
		var ab:=Vector3(a.x,a.y,depth*.5);var bb:=Vector3(b.x,b.y,depth*.5)
		_triangle(v,n,uv,c,ix,Vector3(center.x,center.y,-depth*.5),af,bf,tint)
		_triangle(v,n,uv,c,ix,af,ao,bo,tint.lightened(.23));_triangle(v,n,uv,c,ix,af,bo,bf,tint.lightened(.23))
		_triangle(v,n,uv,c,ix,ao,ab,bb,tint.darkened(.25));_triangle(v,n,uv,c,ix,ao,bb,bo,tint.darkened(.25))
		_triangle(v,n,uv,c,ix,Vector3(center.x,center.y,depth*.5),bb,ab,tint.darkened(.15))

func _gate_fragment(side:float)->ArrayMesh:
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	var outline:=PackedVector2Array([Vector2(.34,.04),Vector2(.82,0),Vector2(.85,1.24),Vector2(.62,1.46),Vector2(.12,1.43),Vector2(.07,1.18),Vector2(.39,1.10)])
	for i in range(outline.size()):outline[i].x*=side
	_extruded(v,n,uv,c,ix,outline,.28,Color(.18,.31,.28))
	var relief:=PackedVector2Array([Vector2(.53,.22),Vector2(.61,.20),Vector2(.62,1.12),Vector2(.52,1.08)])
	for i in range(relief.size()):relief[i].x*=side
	_extruded(v,n,uv,c,ix,relief,.31,Color(.61,.71,.56))
	return _array_mesh(v,n,uv,c,ix)

func _clustered_fractures(radius:float,fortress:bool,width_scale:float=1.0)->ArrayMesh:
	# Terrain breaks under each contact/plate. No line radiates from hero to range edge.
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	var size:=clampf(radius/6.0,.48,1.28)
	var centers:Array[Vector3]=[]
	var angles:Array[float]=[]
	if fortress:
		for gate in range(4):
			var a:=gate*PI*.5+.16;var d:=Vector3(sin(a),0,-cos(a));var side:=Vector3(-d.z,0,d.x)
			for foot in [-1.0,1.0]:
				centers.append(d*(.8+radius*.19)+side*foot*.52*size);angles.append(a+foot*.24)
	else:
		for p in [Vector3(-.72,0,-.35),Vector3(-1.46,0,-.77),Vector3(.12,0,-.86),Vector3(.87,0,.12),Vector3(-1.21,0,.73),Vector3(-.11,0,1.01)]:
			centers.append(p*size);angles.append(float(angles.size())*2.39+.21)
	for cluster in range(centers.size()):
		var center:Vector3=centers[cluster]
		for branch in range(3 if fortress else 4):
			var a:float=angles[cluster]+branch*(1.26 if fortress else 1.61)+.31*sin(cluster*3.1+branch)
			var d:=Vector3(sin(a),0,-cos(a));var side:=Vector3(-d.z,0,d.x)
			var length:float=(.30+.11*((cluster+branch*2)%4))*size
			var prior:=center+side*.06*sin(branch*2.7+cluster)
			for step in range(1,5):
				var t:=step/4.0
				var point:=center+d*length*t+side*sin(cluster*1.73+branch*2.1+step*1.6)*.075*size
				var w:=width_scale*(.023 if fortress else .037)*size*lerpf(1.0,.10,t)
				if step==3 and (branch+cluster)%3==0:prior=point;continue
				var base:=v.size()
				var alpha:float=(.45+.25*absf(sin(cluster+branch*2.4)))*(1.0-t*.28)
				for p in [prior-side*w,prior+side*w,point-side*w*.60,point+side*w*.60]:
					var ground:Vector3=p
					if ground.length()>radius*.97:ground=ground.normalized()*radius*.97
					v.append(ground);n.append(Vector3.UP);uv.append(Vector2(ground.x,ground.z)*3.4)
					c.append(Color(.58,.51,.41,alpha))
				ix.append_array(PackedInt32Array([base,base+1,base+2,base+1,base+3,base+2]));prior=point
	return _array_mesh(v,n,uv,c,ix)

func radial_release(at:Vector3,radius:float,fortress:bool,direction:Vector3=Vector3.FORWARD)->void:
	_ensure_meshes()
	_record("circle",{"radius":radius,"position":at,"fortress":fortress,"style":"releasing_masonry" if fortress else "concentrated_gate_slam"})
	# Local fractured footings react to impact; maximum scatter is bounded by the source radius.
	_spawn(_clustered_fractures(radius,fortress),_surface(Color(.61,.58,.51,.73)),at+Vector3.UP*.033,Basis.IDENTITY,.98,
		{"fade_in":.014,"fade_start":.58,"erosion_start":.5})
	_spawn(_clustered_fractures(radius,fortress,.26),_surface(Color(.46,.68,.59,.49) if fortress else Color(.73,.47,.16,.56),.32),at+Vector3.UP*.037,Basis.IDENTITY,.36,
		{"fade_in":.006,"fade_start":.14,"erosion_start":.2})
	if fortress:
		for i in range(4):
			var d:=Vector3.FORWARD.rotated(Vector3.UP,i*PI*.5+.16);var frame:=_frame(d)
			var start:=maxf(.9,radius*.18)
			for side in [-1.0,1.0]:
				_spawn(_gate_fragment(side),_surface(Color(.86,1.0,.90,.90),.12),at+d*start+Vector3.UP*.035,frame,.47,
					{"architectural_piece":true,"velocity":d*(radius*.52/.32)+Vector3.UP*.52,"gravity":4.5,"spin":Vector3(.18,side*.32,side*.10),
					"stone":true,"ground_y":at.y+.015,"fade_in":.015,"fade_start":.43})
			_scour(at+d*radius*.49,d,Vector2(1.42,radius*.42),.94,.028*i)
			_low_dust(at+d*radius*.54,d,i,1.05,.035+i*.023)
			_plate(at+d*radius*.45,d,i,Vector3(.56,.18,.64),1.25,.018*i)
	else:
		var frame:=_frame(direction);var contact:=at+frame*Vector3(-.75,.035,-.35)
		_scour(contact, direction,Vector2(3.0,3.4),1.05)
		_spawn(_ground,_paint(CONTACT_GROUND,true,Color(1.25,1.10,.77,.90),0.0),contact+Vector3.UP*.025,frame,.092,
			{"scale_from":Vector3(2.05,1,1.50),"scale_to":Vector3(2.85,1,1.95),"fade_in":.002,"fade_start":.07,"erosion_start":1.0})
		_spawn(_quad,_paint(CONTACT,true,Color(1.12,.96,.67,.86),0.0),contact+Vector3.UP*.35,frame,.10,
			{"scale_from":Vector3(1.5,.84,1),"scale_to":Vector3(1.88,.56,1),"billboard":true,"roll":-.18,"fade_in":.002,"fade_start":.05,"erosion_start":1.0})
		var angles:=[-1.05,-.52,.06,.71,1.61,2.46]
		for i in range(angles.size()):
			var d:=direction.rotated(Vector3.UP,angles[i]);var rr:float=radius*([.27,.40,.31,.42,.24,.37][i])
			_plate(at+d*rr,d,i,Vector3(.76+.15*(i%3),.18+.05*(i%2),.89+.12*(i%2)),2.0+.32*(i%3),.008*i)
			_low_dust(at+d*(rr+.18),d,i,1.08+.15*(i%2),.033+.018*i)
			if i%2==0:_scour(at+d*rr,d,Vector2(1.2,1.72),.91,.015*i)

func rectangle(at: Vector3, direction: Vector3, length: float, width: float) -> void:
	_ensure_meshes()
	var frame := _frame(direction)
	_record("rectangle",{"length":length,"width":width,"position":at,"direction":direction})
	_spawn(_rectangle_mesh(length,width,false),_paint(FAULTS,false,Color(0.68,0.72,0.66,0.60)),at+Vector3.UP*0.035,frame,0.66,
		{"reveal_time":0.075,"fade_start":0.48,"erosion_start":0.44})
	_spawn(_rectangle_mesh(length,width,true),_pressure_paint(STEEL),at+Vector3.UP*0.065,frame,0.31,
		{"fade_in":0.009,"fade_start":0.18,"erosion_start":0.19})
	_spawn(_rectangle_mesh(length,width,true),_pressure_paint(Color(0.87,1.0,0.94,0.44)),at+Vector3.UP*0.09,frame,0.18,
		{"fade_in":0.0,"fade_start":0.1,"erosion_start":0.12})
	# A squared broken pressure front sits exactly at the event endpoint. It remains
	# open in the center so the footprint never becomes a solid ground UI rectangle.
	for side in [-1.0,1.0]:
		var stop_edge:=_rectangle_mesh(0.36,width*0.43,true)
		_spawn(stop_edge,_pressure_paint(Color(0.73,0.95,0.88,0.82)),at+frame*Vector3(side*width*0.285,0.07,-length+0.36),frame,0.34,
			{"fade_in":0.008,"fade_start":0.27,"erosion_start":0.28})
	# Parallel ploughed seams make the rectangular width and squared-off end distinct from Q3.
	for side in [-1.0,1.0]:
		var seam := _rectangle_mesh(length,width*0.18,false)
		_spawn(seam,_paint(SCAR,false,Color(1.0,0.96,0.77,0.91)),at+frame*Vector3(side*width*0.41,0.045,0),frame,0.72,
			{"reveal_time":0.055,"fade_start":0.53,"erosion_start":0.48})
	for side in [-1.0,1.0]:
		_spawn(_rocks[1 if side<0 else 4],_stone_paint(),at+frame*Vector3(side*width*0.32,0.14,-length*0.76),frame,0.62,
			{"velocity":direction*1.2+Vector3.UP*2.2,"gravity":15.0,"scale_from":Vector3(width*0.26,0.24,0.52),
			"spin":Vector3(1.7,0,0.3*side),"stone":true,"ground_y":at.y+0.06,"fade_in":0.0,"fade_start":0.7})
	dust(at+direction*length*0.77,direction,width*0.31,3,1.0)
	stones(at+direction*length*0.66,4,0.90,direction)


func field_start(at: Vector3, radius: float) -> void:
	_ensure_meshes()
	_record("shieldfield",{"radius":radius,"position":at})
	# Four small ground contacts announce anchors; never fill the field with a disc.
	for i in range(4):
		var d := Vector3.FORWARD.rotated(Vector3.UP,(i+0.5)*PI*0.5)
		dust(at+d*radius*0.85,d,0.1,1,0.8)

func charge_scrape(at: Vector3, direction: Vector3, ultimate: bool, count: int = 1) -> void:
	_ensure_meshes()
	var frame := _frame(-direction)
	var width := 0.23 if ultimate else 0.18
	var length := 1.20 if ultimate else 0.90
	for side in [-1.0,1.0]:
		_spawn(_rectangle_mesh(length,width,false),_paint(SCAR,false,Color(0.76,0.67,0.48,0.58)),
			at+_frame(direction)*Vector3(side*(0.85 if ultimate else 0.70),0.035,0.35),frame,0.31,
			{"fade_in":0.0,"fade_start":0.22,"erosion_start":0.28})
	# Later R2 charges get heavier kicked dust without changing an authoritative hit footprint.
	dust(at-direction*0.65,-direction,1.0,2,0.66+(count-1)*0.07 if ultimate else 0.62)
