extends RefCounted
## Source-owned HP only. No hit stun, invulnerability, healing or damage writes.
const LIFE:float=2.0
var scope:String=""
var sequence:int=-1
var time:float=-INF
var prior_ratio:float=0
var damage_direction:=Vector3.ZERO
func clear()->void:
 scope="";sequence=-1;time=-INF;prior_ratio=0;damage_direction=Vector3.ZERO
func _sync(sim:Node)->void:
 var current:String="%d|%s|%d"%[sim.get_instance_id(),str(sim.room_id),int(sim.encounter_generation)]
 if scope!=current:clear();scope=current
func _vitals(sim:Node)->bool:
 return is_finite(float(sim.hero.hp)) and is_finite(float(sim.hero.stats.max_hp)) and float(sim.hero.stats.max_hp)>0
func accept(event:Dictionary,sim:Node)->bool:
 _sync(sim)
 if sim.phase!="combat" or sim.hero.dead or not _vitals(sim):return false
 if str(event.get("kind",""))!="damage" or str(event.get("target",""))!="fengli" or bool(event.get("replay",false)) or bool(event.get("stale_generation",false)):return false
 if int(event.get("generation",-1))!=int(sim.encounter_generation) or str(event.get("room_id",""))!=str(sim.room_id):return false
 if not event.get("sequence") is int or int(event.sequence)<=sequence:return false
 var amount:Variant=event.get("amount");var when:Variant=event.get("real_time")
 if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)<=0:return false
 if not (when is int or when is float) or not is_finite(float(when)) or absf(float(when)-float(sim.real_time))>.00001:return false
 # Only current source emissions may create a hurt cue, never a guessed hit.
 if sim.event_log.is_empty() or sim.event_log.back()!=event:return false
 var maximum:float=float(sim.hero.stats.max_hp)
 var before:float=clampf((float(sim.hero.hp)+float(amount))/maximum,0,1)
 # Multiple actual losses in one short burst merge one bounded tail.
 prior_ratio=maxf(before,prior_ratio) if float(when)-time<.35 else before
 var direction:Variant=event.get("direction",Vector3.ZERO)
 damage_direction=direction.normalized() if direction is Vector3 and direction.is_finite() and direction.length_squared()>.00001 else Vector3.ZERO
 time=float(when);sequence=int(event.sequence)
 return true
func sample(sim:Node)->Dictionary:
 _sync(sim)
 if sim.phase!="combat" or sim.hero.dead or not _vitals(sim):return {}
 var age:float=float(sim.real_time)-time
 if not is_finite(age) or age<0 or age>LIFE:return {}
 var hp:float=clampf(float(sim.hero.hp),0,float(sim.hero.stats.max_hp))
 var maximum:float=float(sim.hero.stats.max_hp);var ratio:float=hp/maximum
 var tail:float=lerpf(prior_ratio,ratio,clampf((age-.25)/.55,0,1))
 return {"damage_direction":damage_direction,"recoil":pow(clampf(1-age/.24,0,1),2),"hp":hp,"maximum":maximum,"ratio":ratio,"tail_ratio":maxf(ratio,tail),"pulse":clampf(1-age/.16,0,1),"alpha":clampf((LIFE-age)/.3,0,1),"age":age,"sequence":sequence,"damage_authority":false}
func draw(view:CanvasItem,sim:Node,at:Vector2,font:Font)->Dictionary:
 var value:Dictionary=sample(sim)
 if value.is_empty():return value
 var alpha:float=value.alpha
 var origin:Vector2=at+Vector2(-34,13)
 view.draw_rect(Rect2(origin-Vector2(2,2),Vector2(72,10)),Color(.04,.05,.10,.95*alpha))
 view.draw_rect(Rect2(origin,Vector2(68,6)),Color(.20,.10,.16,alpha))
 view.draw_rect(Rect2(origin,Vector2(68*value.tail_ratio,6)),Color(1,.65,.25,alpha))
 view.draw_rect(Rect2(origin,Vector2(68*value.ratio,6)),Color(.25,.89,.82,alpha))
 var border:=Color(1,.35,.42,alpha).lerp(Color(1,.95,.87,alpha),value.pulse)
 view.draw_rect(Rect2(origin-Vector2(1,1),Vector2(70,8)),border,false,1)
 var label:String="HP %.0f/%.0f"%[value.hp,value.maximum]
 var text_at:Vector2=at+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x*.5,33)
 view.draw_string_outline(font,text_at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(.04,.05,.10,alpha))
 view.draw_string(font,text_at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,.95,.95,alpha))
 return value
