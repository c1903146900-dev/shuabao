extends "res://tests/ink_initial_hex_ui_20261004/fix01/session.gd"
## Initial modal/input/progression/room lifecycle remains inherited unchanged.
## Only the fresh exact Bridge/Binding constructors differ from fix01.
const IntermediateBridge = preload("res://tests/ink_normal_floor_host_20261004/bridge.gd")
const IntermediateBinding = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")

const RewardAdapter = preload("res://tests/ink_first_floor_rewards_fix01_20261004/reward_adapter.gd")
var reward_configuration: Dictionary = {}
func configure_reward_table(table_path: String, csv_path: String, receipt_path: String, allow_trial: bool = false) -> Dictionary:
 if status != "unbound" or not reward_configuration.is_empty(): return _deny("fresh_reward_configuration_required")
 var checked: Dictionary = RewardAdapter.load_table(table_path, csv_path, receipt_path, allow_trial)
 if not checked.accepted: return checked
 reward_configuration = {"table":table_path,"csv":csv_path,"receipt":receipt_path,"allow":allow_trial}
 return {"accepted":true,"reason":"","binding":checked.binding.duplicate(true)}

func initialize_session(source_sim: Node, new_run_id: String, diagnostic: bool = false) -> Dictionary:
 if status != "unbound" or not is_instance_valid(source_sim) or new_run_id.is_empty(): return _deny("fresh_session_required")
 var admission: Dictionary = IntermediateBinding.read_capabilities(source_sim, true)
 if not admission.accepted: return admission
 var candidate = IntermediateBridge.new()
 if reward_configuration.is_empty(): return _deny("explicit_reward_table_required")
 var configured: Dictionary = candidate.configure_reward_table(reward_configuration.table, reward_configuration.csv, reward_configuration.receipt, reward_configuration.allow)
 if not configured.accepted: return configured
 var initialized: Dictionary = candidate.initialize_runtime_fixture(source_sim, admission.capabilities, SHOP, FIXTURE, NUMERIC, self, new_run_id, true)
 if not initialized.accepted: return initialized
 var fresh: Dictionary = candidate.model.snapshot()
 if fresh.level != 1 or fresh.gold != 0 or fresh.xp != 0 or fresh.points != 1 or not fresh.inventory.is_empty() or not fresh.selected_hex.is_empty(): return _deny("fresh_zero_gold_authority_required")
 for skill in fresh.skills.values():
  if skill.rank != 0 or not str(skill.candidate).is_empty(): return _deny("fresh_unlearned_authority_required")
 var bound: Dictionary = candidate.model.bind_floor(self, source_sim, new_run_id)
 if not bound.accepted: return bound
 sim = source_sim; ledger = candidate; run_id = new_run_id
 initial_flow_diagnostic = diagnostic
 diagnostic_run = false # Never use the ancestor's Hex-skipping 23-kill branch.
 consumers = InitialConsumer.new()
 sim.set_progression(ledger); sim.auto_finish = false
 route = {"floor_id":"initial_hex_one_ai_diagnostic" if diagnostic else "ordinary_first_floor_pending", "version":"initial-hex-ui-01", "content_status":"explicit_one_ai_after_actual_initial_choice" if diagnostic else "pending_authoring", "nodes":[{"id":"one_original_ai", "kind":"ordinary", "training_after":false}] if diagnostic else []}
 status = "preparation"; growth_dirty = true
 var entered: Dictionary = _authority("enter_room", {"next_room":run_id + "/initial-safe"})
 if not entered.accepted: return entered
 session_events.append({"type":"initialized", "initial_flow_diagnostic":diagnostic, "level":fresh.level, "gold":fresh.gold, "xp":fresh.xp, "points":fresh.points, "initial_hex_skipped":false, "automatic_learning":false})
 return {"accepted":true, "reason":"", "initial_flow_diagnostic":diagnostic}


func submit(id: String, action: String, args: Dictionary) -> Dictionary:
 if action != "craft": return super.submit(id, action, args)
 # Same original panel/safe/transaction guards; only craft joins the UI allowlist.
 if not panel_open: return _record(_deny("shop_panel_not_open"))
 var reason: String = safe_shop_reason()
 if not reason.is_empty(): return _record(_deny(reason))
 var result: Dictionary = ledger.shop_command(id, action, args)
 if result.accepted: growth_dirty = true
 return _record(result)
