extends "res://elixir_war_20261009/session.gd"
## One retained ordinary Session and all original wallet/health/rest authorities.
const R2OrdinaryBinding = preload("res://visual_rework_20261009/binding/live_binding.gd")
const R2OrdinaryBridge = preload("res://visual_rework_20261009/binding/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return R2OrdinaryBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return R2OrdinaryBridge.new()

func set_modal_blocked(blocked:bool)->Dictionary:
 if status!="completed":return super.set_modal_blocked(blocked)
 # A settled victorious run retains its original safe learning/shop authority.
 # Only the UI modal lifecycle is admitted; no room/phase/reward clock is resumed.
 if not is_instance_valid(sim) or sim.transaction_active:return _deny("defer_modal_to_outer_boundary")
 if not _owner_intact() or sim.hero.dead or sim.phase!="victory" or ledger.model.state.phase!="safe" or settlement.get("outcome","")!="victory":return _deny("settled_victory_required")
 if blocked==initial_modal_open:return {"accepted":true,"reason":"unchanged"}
 if not _input_suspender.is_valid():return _deny("input_suspender_missing")
 if blocked:_initial_prior_pause=sim.paused
 _input_suspender.call("initial_hex_open" if blocked else "initial_hex_close_release_required")
 sim.hero.move_intent=Vector3.ZERO
 initial_modal_open=blocked
 sim.paused=true if blocked else (_initial_prior_pause or initial_focus_pause)
 return {"accepted":true,"reason":"","paused":sim.paused,"terminal_ui_only":true}
