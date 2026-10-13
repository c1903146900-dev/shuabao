extends "res://assets/fengli/vfx/q1_thrust.gd"
## Short art-only pressure around the forward sword lunge; source2m reach unchanged.
func advance(dt:float)->void:
 super.advance(dt*(.32/.22))
