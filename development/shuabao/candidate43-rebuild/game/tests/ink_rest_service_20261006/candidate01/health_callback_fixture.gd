extends "res://tests/ink_rest_service_20261006/candidate01/rest_service.gd"
## Test-only one-shot callback injection AFTER the real commerce entry committed.
## No production health owner is replaced during an economic transaction.
var observer: RefCounted
var original_owner: RefCounted
func _clear_live_state(sim: Node) -> void:
 super._clear_live_state(sim)
 if observer == null: return
 if original_owner == null:
  original_owner = sim._equipment_health_owner.get_ref()
  observer.source = original_owner
  sim._equipment_health_owner = weakref(observer)
 else:
  sim._equipment_health_owner = weakref(original_owner)
