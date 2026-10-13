extends "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd"
## Observes actual hero HP mutations; original damage/heal/clock/input algorithms stay inherited.
## This revision is a dependency serial, not a second health or economy authority.
var equipment_health_revision: int = 0
var _equipment_health_owner: WeakRef
var _equipment_projection_depth: int = 0
var _observed_equipment_hp: float = NAN
func bind_equipment_health(owner: RefCounted) -> Dictionary:
 if owner==null or _equipment_health_owner!=null:return {"accepted":false,"reason":"health_observer_already_bound"}
 _equipment_health_owner=weakref(owner);_observed_equipment_hp=hero.hp
 return {"accepted":true,"reason":""}
func observe_pending_health() -> void:
 if not is_finite(_observed_equipment_hp):_observed_equipment_hp=hero.hp;return
 if hero.hp!=_observed_equipment_hp:_health_changed("unobserved_actual_hp_change",_observed_equipment_hp,hero.hp)
func begin_equipment_projection(owner: RefCounted) -> bool:
 if _equipment_health_owner==null or not is_same(_equipment_health_owner.get_ref(),owner) or _equipment_projection_depth!=0:return false
 observe_pending_health();_equipment_projection_depth=1
 return true
func end_equipment_projection(owner: RefCounted) -> void:
 assert(_equipment_health_owner!=null and is_same(_equipment_health_owner.get_ref(),owner) and _equipment_projection_depth==1)
 _equipment_projection_depth=0;_observed_equipment_hp=hero.hp
func _health_changed(kind: String, before: float, after: float) -> void:
 if before==after:return
 _observed_equipment_hp=after
 if _equipment_projection_depth>0:return
 equipment_health_revision+=1
 if _equipment_health_owner!=null and _equipment_health_owner.get_ref()!=null:
  _equipment_health_owner.get_ref().record_health_dependency(self,kind,equipment_health_revision,before,after)
func damage_hero(amount: float, direction: Vector3=Vector3.ZERO, control: float=0.0, is_true: bool=false, mandatory: bool=false, metadata: Dictionary={}) -> void:
 observe_pending_health()
 var before: float=hero.hp
 super.damage_hero(amount,direction,control,is_true,mandatory,metadata)
 _health_changed("source_damage",before,hero.hp)
func heal_actor(actor: RefCounted, amount: float, metadata: Dictionary={}) -> float:
 if actor==hero:observe_pending_health()
 var before: float=hero.hp
 var actual: float=super.heal_actor(actor,amount,metadata)
 if actor==hero:_health_changed("source_heal:"+str(metadata.get("source","heal")),before,hero.hp)
 return actual
func apply_committed_health_loss(amount: float, nonlethal: bool=false, metadata: Dictionary={}) -> float:
 observe_pending_health()
 var before: float=hero.hp
 var actual: float=super.apply_committed_health_loss(amount,nonlethal,metadata)
 _health_changed("source_committed_health_loss",before,hero.hp)
 return actual
func set_projected_stats(projected: Dictionary) -> void:
 observe_pending_health()
 var before: float=hero.hp
 super.set_projected_stats(projected)
 _health_changed("external_projection_actual_hp_change",before,hero.hp)
func _fixed_step(real_dt: float) -> void:
 observe_pending_health()
 super._fixed_step(real_dt)
 # Catch shared direct clamps or future inherited HP writes, but no-op refreshes
 # and already-observed damage/healing do not advance the dependency serial.
 observe_pending_health()
func _hero_snapshot() -> Dictionary:
 var out: Dictionary=super._hero_snapshot()
 out["equipment_health_dependency_revision"]=equipment_health_revision
 return out
