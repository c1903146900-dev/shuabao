class_name XuanleiBasicAttacksVFX
extends "res://assets/xuanlei/vfx/cuicheng.gd"
## Motion comes from actual imported weapon sockets. Contact comes from damage.
## A miss can have an air wake and displacement dust; never a contact packet.
const WAKE := preload("res://assets/xuanlei/vfx/basic/forged_wake.png")
const CONTACT_SHADER := preload("res://assets/xuanlei/vfx/basic/contact.gdshader")
const CUT := preload("res://assets/xuanlei/vfx/basic/contact_cut.png")
const CRUSH := preload("res://assets/xuanlei/vfx/basic/contact_crush.png")
const FILING := preload("res://assets/xuanlei/vfx/basic/filing.png")
const WINDOWS := {"attack_1":Vector2(.10,.23),"attack_2":Vector2(.08,.20),"attack_3":Vector2(.12,.255),"dash_attack":Vector2(.035,.24)}
var _attack_clip := ""
var _cast := -1
var _clock := 0.0
var _history: Array[Dictionary] = []
var _trail: MeshInstance3D
var _last_origin := Vector3.ZERO
var _dash_distance := 0.0
var _dust_count := 0
var _sample_clock := -1.0
var _fragment_cache: Dictionary = {}
var receipts: Array[Dictionary] = []
var motion_sample_count := 0
var contact_count := 0
var peak_wake_area := 0.0
var _dash_head:MeshInstance3D
var _dash_echoes:=0
var dash_echo_count:=0

func begin_attack(clip:String, cast_id:int, view:Node3D) -> void:
	if not WINDOWS.has(clip):return
	if cast_id==_cast and clip==_attack_clip:return
	_attack_clip=clip;_cast=cast_id;_history.clear();_sample_clock=-1.0
	_dash_distance=0;_dust_count=0
	_dash_echoes=0
	if is_instance_valid(view):_last_origin=view.global_position
	_ensure_meshes()
	if not is_instance_valid(_trail):
		_trail=MeshInstance3D.new();_trail.name="ActualWeaponWake";add_child(_trail)
		_trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail.material_override=_paint(WAKE,false,Color(1.30,1.18,.96,.87),0.0)
		_trail.extra_cull_margin=2.0
	_trail.visible=false
	_record_receipt({"kind":"motion_begin","clip":clip,"cast_id":cast_id})

func cancel_attack(cast_id:int=-1) -> void:
	if cast_id>=0 and cast_id!=_cast:return
	_attack_clip="";_history.clear()
	if is_instance_valid(_trail):_trail.visible=false
	if is_instance_valid(_dash_head):_dash_head.visible=false
	for i in range(_live.size()-1,-1,-1):
		if _live[i].get("dash_motion",false):
			if is_instance_valid(_live[i].node):_live[i].node.free()
			_live.remove_at(i)

func clear_transients() -> void:
	super.clear_transients();cancel_attack();_cast=-1

func get_live_count() -> int:
	return super.get_live_count()+(1 if is_instance_valid(_trail) and _trail.visible else 0)+(1 if is_instance_valid(_dash_head) and _dash_head.visible else 0)

func debug_snapshot() -> Dictionary:
	return {"clip":_attack_clip,"cast_id":_cast,"history_samples":_history.size(),"motion_samples":motion_sample_count,"contact_count":contact_count,"live":get_live_count(),"peak_wake_area_m2":peak_wake_area,"dash_echo_count":dash_echo_count,"dash_head_visible":is_instance_valid(_dash_head) and _dash_head.visible,"receipts":receipts.duplicate(true)}

func _record_receipt(receipt:Dictionary) -> void:
	receipts.append(receipt)
	if receipts.size()>64:receipts.pop_front()

func _socket(skeleton:Skeleton3D, socket:String) -> Vector3:
	var index:=skeleton.find_bone(socket)
	if index<0:return skeleton.global_position
	return skeleton.global_transform*skeleton.get_bone_global_pose(index).origin

func sample_weapon(view:Node3D, dt:float) -> void:
	_clock+=maxf(0,dt)
	while not _history.is_empty() and _clock-float(_history[0].time)>.090:_history.pop_front()
	if not is_instance_valid(view) or not is_instance_valid(view.skeleton):
		cancel_attack();return
	if _attack_clip.is_empty():
		if is_instance_valid(_trail):_trail.visible=false
		if is_instance_valid(_dash_head):_dash_head.visible=false
		return
	var t:float=view.sampled_time
	var matching:bool=view.anim==_attack_clip
	var window:Vector2=WINDOWS[_attack_clip]
	if is_instance_valid(_dash_head):_dash_head.visible=false
	if _attack_clip=="dash_attack" and matching and t>=.035 and t<=.20:
		_dash_pressure(view,t)
	if matching and t>=window.x-.021 and t<=window.y and dt>0 and not is_equal_approx(_sample_clock,t):
		_sample_clock=t
		var skeleton:Skeleton3D=view.skeleton
		skeleton.force_update_all_bone_transforms()
		var a:Vector3
		var b:Vector3
		if _attack_clip=="attack_2":
			a=_socket(skeleton,"socket_chain");b=_socket(skeleton,"socket_chain_tip")
			# The proximal whip remains attached to the fist; a small extension of
			# edge width is material wake, not a weapon reaching outside the rig.
			a=a.lerp(b,.13);b=a.lerp(b,.82)
		else:
			a=_socket(skeleton,"socket_gate_crown_L")
			b=_socket(skeleton,"socket_gate_crown_R")
		# Material pressure rides just beyond the moving physical edge. The offset
		# is bounded in meters and derived from its actual measured velocity.
		if not _history.is_empty():
			var prior:Dictionary=_history[-1]
			var advance_a:Vector3=a-Vector3(prior.get("raw_a",prior.a))
			var advance_b:Vector3=b-Vector3(prior.get("raw_b",prior.b))
			var raw_a:=a;var raw_b:=b
			if advance_a.length_squared()>.00001:a+=advance_a.normalized()*.16
			if advance_b.length_squared()>.00001:b+=advance_b.normalized()*.16
			var across:Vector3=(b-a).normalized()
			a-=across*.10;b+=across*.10
			_history.append({"a":a,"b":b,"raw_a":raw_a,"raw_b":raw_b,"time":_clock});motion_sample_count+=1
		else:
			_history.append({"a":a,"b":b,"raw_a":a,"raw_b":b,"time":_clock});motion_sample_count+=1
		if _attack_clip=="dash_attack":
			var displacement:Vector3=view.global_position-_last_origin
			_dash_distance+=displacement.length()
			if _dash_distance>.55 and _dust_count<4:
				_dash_distance=0;_dust_count+=1
				var direction:=displacement.normalized() if displacement.length_squared()>.0001 else -view.global_basis.z
				_movement_dust(view.global_position-direction*.45,direction,_dust_count)
	_last_origin=view.global_position
	# Pre-sampling seeds geometric history only; the wake cannot render before release.
	if t>=window.x:_draw_wake()
	elif is_instance_valid(_trail):_trail.visible=false
	if (not matching or t>window.y+.10) and _history.is_empty():_attack_clip=""

func _dash_pressure(view:Node3D,t:float)->void:
	var skeleton:Skeleton3D=view.skeleton
	skeleton.force_update_all_bone_transforms()
	var a:=_socket(skeleton,"socket_gate_crown_L")
	var b:=_socket(skeleton,"socket_gate_crown_R")
	var low:=_socket(skeleton,"socket_gate_cut_low")
	var forward:Vector3=-view.global_basis.z.normalized()
	# Two brief broken impressions use the actual transformed gate perimeter.
	# They are wake remnants, with open centers, never independent flying gates.
	if (_dash_echoes==0 and t>=.065) or (_dash_echoes==1 and t>=.115):
		_dash_echoes+=1;dash_echo_count+=1
		_dash_gate_echo(a,b,low,forward,_dash_echoes)
	if not is_instance_valid(_dash_head):
		_dash_head=MeshInstance3D.new();_dash_head.name="DashSplitPressureHead";add_child(_dash_head)
		_dash_head.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dash_head.material_override=_paint(WAKE,false,Color(1.38,1.24,.94,.90),0.0)
		_dash_head.extra_cull_margin=2.0
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	var ramp:=clampf((t-.035)/.022,0,1)*clampf((.20-t)/.075,0,1)
	var down:=low-b
	# Unequal pressure lobes hug the crown, extend only 26cm beyond the rim,
	# and peel backward. Their split is aligned to the gate, not the camera.
	for side in range(2):
		var lo:=.02 if side==0 else .55
		var hi:=.46 if side==0 else .96
		var p:Vector3=a.lerp(b,lo);var q:Vector3=a.lerp(b,hi)
		var width:=.24 if side==0 else .18
		var points:Array[Vector3]=[p-forward*.35+down*.10,p+forward*.24-down*width,q+forward*.26-down*(width*.72),q-forward*.23+down*.055]
		var k:=v.size()
		for j in range(4):
			v.append(points[j]);n.append(Vector3.UP);uv.append([Vector2(.02,1),Vector2(.82,0),Vector2(1,0),Vector2(.24,1)][j]);c.append(Color(1,1,1,ramp))
		ix.append_array(PackedInt32Array([k,k+1,k+2,k,k+2,k+3]))
	_dash_head.mesh=_array_mesh(v,n,uv,c,ix);_dash_head.global_transform=Transform3D.IDENTITY;_dash_head.visible=ramp>.01

func _dash_gate_echo(a:Vector3,b:Vector3,low:Vector3,forward:Vector3,index:int)->void:
	var down:=low-b
	var center:Vector3=(a+b+down)*.5-forward*.10
	var corners:Array[Vector3]=[a,b,b+down,a+down]
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	# Only three separated pieces of the battered rim survive, no opaque plate.
	for segment in [[0,.04,.84],[1,.08,.56],[3,.30,.88]]:
		var edge:int=segment[0]
		var p:Vector3=corners[edge].lerp(corners[(edge+1)%4],segment[1])
		var q:Vector3=corners[edge].lerp(corners[(edge+1)%4],segment[2])
		var points:Array[Vector3]=[p,q,q.lerp(center,.14),p.lerp(center,.14)]
		var k:=v.size()
		for j in range(4):
			v.append(points[j]-center);n.append(Vector3.UP);uv.append([Vector2(.04,0),Vector2(1,0),Vector2(1,1),Vector2(.04,1)][j]);c.append(Color.WHITE)
		ix.append_array(PackedInt32Array([k,k+1,k+2,k,k+2,k+3]))
	_spawn(_array_mesh(v,n,uv,c,ix),_paint(WAKE,false,Color(1.06,.94,.72,.39 if index==1 else .29),0.0),center,Basis.IDENTITY,.14,
		{"dash_motion":true,"velocity":-forward*.65,"fade_in":.0,"fade_start":.12,"erosion_start":.30})
	_record_receipt({"kind":"dash_gate_echo","cast_id":_cast,"index":index,"source":"actual_gate_socket_transform"})

func _draw_wake() -> void:
	if not is_instance_valid(_trail):return
	if _history.size()<2:
		_trail.visible=false;return
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	var area:=0.0
	for i in range(_history.size()):
		var item:Dictionary=_history[i]
		var freshness:=clampf(1.0-(_clock-float(item.time))/.090,0,1)
		var u:=float(i)/float(_history.size()-1)
		# The tail narrows to its center and breaks into brush texture. The weapon
		# end retains material mass, unlike a constant-width energy ring.
		var center:Vector3=(Vector3(item.a)+Vector3(item.b))*.5
		var width:=lerpf(.08,1.0,pow(u,.62))
		var a:Vector3=center.lerp(item.a,width)
		var b:Vector3=center.lerp(item.b,width)
		v.append(a);v.append(b);n.append(Vector3.UP);n.append(Vector3.UP)
		uv.append(Vector2(u,0));uv.append(Vector2(u,1))
		var alpha:=pow(freshness,.65)*(.55+.45*u)
		c.append(Color(1,1,1,alpha));c.append(Color(1,1,1,alpha))
		if i>0:
			var k:=i*2
			ix.append_array(PackedInt32Array([k-2,k,k-1,k-1,k,k+1]))
			area+=(v[k]-v[k-2]).cross(v[k-1]-v[k-2]).length()*.5+(v[k]-v[k-1]).cross(v[k+1]-v[k-1]).length()*.5
	_trail.mesh=_array_mesh(v,n,uv,c,ix);_trail.global_transform=Transform3D.IDENTITY;_trail.visible=area>.003
	peak_wake_area=maxf(peak_wake_area,area)

func _movement_dust(at:Vector3,direction:Vector3,index:int) -> void:
	var side:=direction.cross(Vector3.UP)
	var origin:=at+side*(.32 if index%2==0 else -.32)+Vector3.UP*.10
	_spawn(_quad,_paint(DUST[index%3],false,Color(.63,.60,.51,.33)),origin,_frame(direction),.23,
		{"velocity":-direction*.90+Vector3.UP*.10,"scale_from":Vector3(.45,.20,1),"scale_to":Vector3(.92,.43,1),"billboard":true,"fade_in":.016,"fade_start":.16,"erosion_start":.20})

func _material_fragment(kind:String) -> Mesh:
	if _fragment_cache.has(kind):return _fragment_cache[kind]
	if kind=="chain":
		var ring:=TorusMesh.new();ring.inner_radius=.23;ring.outer_radius=.47;ring.rings=10;ring.ring_segments=5
		_fragment_cache[kind]=ring;return ring
	var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
	var points: Array[Vector3]
	if kind=="wood":points=[Vector3(-.18,-.14,-.65),Vector3(.21,-.10,-.48),Vector3(.09,.15,.71),Vector3(-.12,.08,.55),Vector3(.0,-.17,.50)]
	else:points=[Vector3(-.45,-.10,-.21),Vector3(.34,-.07,-.35),Vector3(.51,.03,.20),Vector3(-.23,.12,.36),Vector3(.03,.20,-.02)]
	var tint:=Color(.48,.30,.14) if kind=="wood" else Color(.46,.52,.51)
	for face in [[0,1,4],[1,2,4],[2,3,4],[3,0,4],[0,3,2],[0,2,1]]:
		_triangle(v,n,uv,c,ix,points[face[0]],points[face[1]],points[face[2]],tint.lightened(.12 if int(face[0])%2==0 else .0))
	var result:=_array_mesh(v,n,uv,c,ix);_fragment_cache[kind]=result;return result

func contact(at:Vector3,direction:Vector3,combo:int=1,material:String="metal",dash:bool=false,cast_id:int=-1) -> void:
	_ensure_meshes();contact_count+=1
	_record_receipt({"kind":"actual_contact","position":at,"combo":combo,"material":material,"dash":dash,"cast_id":cast_id})
	var frame:=_frame(direction);var heavy:=combo==3 or dash
	var origin:=at-direction*.40+Vector3.UP*(.85 if heavy else 1.15)
	var impact_size:=1.0 if dash else .88 if combo==3 else .71 if combo==2 else .78
	# Tiny camera-readable fractured contact stamp. Two local layers last 65 ms;
	# this cannot be occluded inside thick enemy armor, unlike a centered quad.
	var contact_art:Texture2D=CRUSH if heavy else CUT
	var outline:=_paint(contact_art,false,Color(.075,.065,.045,.90),0.0)
	outline.shader=CONTACT_SHADER;outline.render_priority=1
	_spawn(_quad,outline,origin,frame,.060,
		{"scale_from":Vector3(.98,1.33,1)*impact_size,"scale_to":Vector3(1.30,1.06,1)*impact_size,"billboard":true,"roll":-.42 if combo==1 else .72 if combo==2 else .04,"fade_in":.002,"fade_start":.10,"erosion_start":1.0})
	var contact_paint:=_paint(contact_art,false,Color(1.25,1.17,.95,1.0),0.0)
	contact_paint.shader=CONTACT_SHADER;contact_paint.render_priority=2
	_spawn(_quad,contact_paint,origin,frame,.065,
		{"scale_from":Vector3(.85,1.18,1)*impact_size,"scale_to":Vector3(1.15,.91,1)*impact_size,"billboard":true,"roll":-.42 if combo==1 else .72 if combo==2 else .04,"fade_in":.002,"fade_start":.16,"erosion_start":1.0})
	# Physical debris follows the receiver's material. Short chain pieces belong
	# to the hooked second strike, never all three moves indiscriminately.
	var fragment_kind:=material if material in ["metal","wood","stone","chain"] else "metal"
	for i in range(5 if heavy else 3):
		var a:=float(i)*2.399+.25*combo
		var lateral:=frame.x*sin(a)
		var velocity:=lateral*(1.35+.35*(i%2))+direction*(.7 if dash else .20)+Vector3.UP*(1.45+.3*(i%3))
		if combo==1:velocity+=frame.x*.75
		if combo==2:velocity-=frame.x*.65
		var debris:String="chain" if combo==2 and i==0 else fragment_kind
		var mesh:Mesh=_rocks[i%6] if debris=="stone" else _material_fragment(debris)
		var size:=Vector3(.17,.11,.25) if debris=="wood" else Vector3.ONE*.14 if debris=="chain" else Vector3(.18,.10,.24)
		if heavy:size*=1.25
		var shader:=_stone_paint()
		_spawn(mesh,shader,origin+frame.x*(.075*sin(a)),Basis.from_euler(Vector3(.4,a,.1)),.32+.045*(i%3),
			{"velocity":velocity,"gravity":17.0,"scale_from":size,"spin":Vector3(3.5,a,2.0),"stone":true,"ground_y":at.y+.02,"fade_in":0.0,"fade_start":.54})
	# Material pressure is an unequal pair of low puffs with negative space.
	for i in range(2 if heavy else 1):
		var low:=at+Vector3.UP*(.17 if heavy else .73)+frame.x*(.18 if i==0 else -.23)
		var tint:=Color(.76,.67,.49,.46) if fragment_kind=="wood" else Color(.74,.73,.65,.39)
		_spawn(_quad,_paint(DUST[(combo+i)%3],false,tint),low,frame,.27 if heavy else .21,
			{"velocity":direction*(.55 if dash else .15)+frame.x*(.45 if i==0 else -.52)+Vector3.UP*.20,"scale_from":Vector3(.55,.30,1)*impact_size,"scale_to":Vector3(1.25,.70,1)*impact_size,"billboard":true,"roll":-.2+.3*i,"fade_in":.013,"fade_start":.21,"erosion_start":.22})
	if fragment_kind in ["metal","chain"] or combo==2:
		for i in range(3 if heavy else 2):
			var velocity:=frame.x*(-1.3+i*1.15)+Vector3.UP*(.9+.3*i)-direction*.35
			_spawn(_quad,_paint(FILING,false,Color(1.18,1.04,.80,.88),0.0),origin,frame,.12+.025*i,
				{"velocity":velocity,"gravity":8.0,"scale_from":Vector3(.035,.26+.07*i,1),"billboard":true,"roll":-.9+.8*i,"fade_in":0.0,"fade_start":.08,"erosion_start":1.0})
