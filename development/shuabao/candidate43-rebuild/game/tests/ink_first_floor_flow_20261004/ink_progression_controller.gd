extends "res://scripts/ui/progression_controller.gd"
## Preserve mandatory offer; distinguish an unsupported pool from an ordinary unanswered choice.
var _last_pool_hold := ""

func initial_pool_readiness() -> Dictionary:
 if model == null: return {"accepted":false, "reason":"ink_ledger_unavailable"}
 var eligible := 0
 var personal := 0
 var effects: Dictionary = {}
 for id in definitions.hexes:
  var entry: Dictionary = definitions.hexes[id]
  if id in model.state.selected_hex or not model.support(entry).supported: continue
  if effects.has(entry.effect_key): continue
  effects[entry.effect_key] = true
  eligible += 1
  if entry.hero == "yanguizhou": personal += 1
 return {"accepted":eligible >= 4 and personal >= 1, "reason":"" if eligible >= 4 and personal >= 1 else "mandatory_hex_pool_not_ready", "eligible":eligible, "personal":personal}

func ensure_auto_hex() -> void:
 if not auto_hex_pending():
  _last_pool_hold = ""
  super.ensure_auto_hex()
  return
 var current: Dictionary = model.snapshot()
 var key: String = str(current.pending_milestones[0])
 var ready: Dictionary = initial_pool_readiness()
 if not current.offers.has(key) and not ready.accepted:
  # Do not forge slots, skip Lv1 or enable unimplemented Hexes to make this green.
  hud.set_hex_required(true)
  if _last_pool_hold != ready.reason:
   _last_pool_hold = ready.reason
   hud.set_receipt("初始海克斯尚未凑齐真实可用候选，普通开战暂不可用", false)
   gameplay_block_changed.emit(true)
  return
 _last_pool_hold = ""
 super.ensure_auto_hex()
