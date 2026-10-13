extends "res://tests/ink_q3_input_growth_20261004/growth_hud.gd"
signal training_requested
func _ready() -> void:
 super._ready()
 # Actual training reset goes through the Session's entered-node API.
 for connection: Dictionary in respec_button.pressed.get_connections():
  respec_button.pressed.disconnect(connection.callable)
 respec_button.pressed.connect(func(): training_requested.emit())
