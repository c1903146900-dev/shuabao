extends RefCounted
var checks:Array=[]
var failures:Array=[]
func check(name:String,ok:bool)->void:
 checks.append({"check":name,"passed":ok})
 if not ok:failures.append(name)
func run()->Dictionary:
 var p=load("res://fengli_route_20261024/puppet_motion.gd").new()
 var e:Dictionary={"kind":"attack_started","combo":1,"animation":{"contact_after":.216666666666667,"recovery":.416666666666667}}
 var before:String=JSON.stringify(e)
 for direction in [Vector2(1,0),Vector2(1,-3),Vector2(1,3),Vector2(0,-1),Vector2(0,1)]:
  check("start_"+str(direction),is_zero_approx(p.basic_aim_pitch(e,0,direction)))
  check("end_"+str(direction),is_zero_approx(p.basic_aim_pitch(e,.633333333333334,direction)))
  for i in range(65):
   var value:float=p.basic_aim_pitch(e,float(i)/100,direction)
   check("bounded_"+str(direction)+"_"+str(i),is_finite(value) and value>=-1.350001 and value<=.650001)
 check("upward_contact",p.basic_aim_pitch(e,.216666666666667,Vector2(1,-3))<-.8)
 check("downward_contact",p.basic_aim_pitch(e,.216666666666667,Vector2(1,3))>.3)
 check("zero_aim",p.basic_aim_pitch(e,.2,Vector2.ZERO)==0)
 check("invalid_aim",p.basic_aim_pitch(e,.2,Vector2(INF,0))==0)
 check("invalid_age",p.basic_aim_pitch(e,INF,Vector2.RIGHT)==0)
 check("event_unchanged",JSON.stringify(e)==before)
 for kind in ["dash","dash_attack_started","q1_started","q2_strike_started","q3_started","e1_pierce_started","e2_spin_started","r1_started"]:
  var other=e.duplicate(true);other.kind=kind
  check("nonbasic_"+kind,p.basic_aim_pitch(other,.2,Vector2(1,-3))==0)
 for mirror in [-1.0,1.0]:
  var visual:=Vector2(mirror,1)*Vector2(.96,1.04)
  var rotation:float=.12*mirror
  var local:=Vector2(.4,-.9)
  var screen:Vector2=(local*visual).rotated(rotation)
  var recovered:Vector2=screen.rotated(-rotation)/visual
  check("inverse_basis_"+str(mirror),recovered.distance_to(local)<.00001)
 return {"checks":checks,"failures":failures,"scope":"Pure visual helper and basis fixture; no native or aesthetic acceptance"}
