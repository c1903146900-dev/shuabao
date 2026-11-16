extends "res://tests/ink_q3_input_growth_20261004/controller.gd"
## Do not open new required-choice UI after this run has already ended.
## Pending milestones/rewards remain owned by the original progression model.
func auto_hex_pending()->bool:
 if _session==null:return false
 var session=_session.get_ref()
 if session==null or session.status not in ["preparation","combat","between_rooms","service"]:return false
 return super.auto_hex_pending()
