extends "res://tests/combat/harness.gd"
func qa_prepare_attack():
 get_window().title="QA_WINDOW_INPUT"
 get_window().size=Vector2i(1280,720)
 begin_input_probe("attack")
 simulation.auto_finish=true
 simulation.enemies[0].hp=64
 simulation.enemies[0].max_hp=64
 return qa_read()
func qa_read():
 return JSON.stringify({"snapshot":simulation.snapshot(),"events":simulation.event_log,"input":probe_events,"held_keys":held_keys,"mouse_pressed":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)})
