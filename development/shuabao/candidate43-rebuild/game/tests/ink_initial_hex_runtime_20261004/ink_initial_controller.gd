extends "res://tests/ink_first_floor_flow_20261004/ink_progression_controller.gd"
## Ordinary HexUI still uses the inherited real command path and gameplay pause.
func initial_pool_readiness()->Dictionary:
 if model==null:return {"accepted":false,"reason":"ink_ledger_unavailable"}
 return model.initial_pool_readiness()
