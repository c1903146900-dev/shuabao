extends RefCounted
## Source-only bridge to the editable numeric producer. Never parse stale prose as edited numbers.
static func build(source_fixture: Dictionary, numeric: Dictionary) -> Dictionary:
 if numeric.get("schema_version", "") != "1.0.0-source-foundation": return _deny("numeric_schema_mismatch")
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var result: Dictionary = source_fixture.duplicate(true)
 for id in result.items:
  var price: Dictionary = numeric.parameters.get(str(id) + ".price", {})
  if not _money(price.get("value", null)): return _deny("invalid_price:" + str(id))
  result.items[id].price = int(price.value)
  if result.items[id].kind in ["potion", "flask"]:
   var heal: Dictionary = numeric.parameters.get(str(id) + ".heal_max_health_pct", {})
   var duration: Dictionary = numeric.parameters.get(str(id) + ".duration", {})
   if not _positive(heal.get("value", null)) or not _positive(duration.get("value", null)): return _deny("invalid_recovery:" + str(id))
   result.items[id].recovery.heal_max_health_pct = heal.value
   result.items[id].recovery.duration_seconds = duration.value
 var body: Dictionary = numeric.parameters.get("training:global.price", {})
 if not _money(body.get("value", null)): return _deny("invalid_body_price")
 result.body_price = int(body.value)
 # Slot/session safeguards belong to effective rules, not the historical catalog prose.
 var effective: Dictionary = numeric.get("effective_user_override", {})
 if not effective.get("ordinary_equipment_undo", {}).get("commit_on_entering_any_next_room", false): return _deny("effective_room_commit_override_missing")
 if not effective.get("consumable_slots", {}).get("elixirs_occupy_six_equipment_slots", false): return _deny("effective_slot_override_missing")
 result["numeric_projection_status"] = "editable_values_projected_not_balance_validated"
 return {"accepted":true, "reason":"", "definitions":result}

static func _money(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floor(float(value))

static func _positive(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) > 0

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
